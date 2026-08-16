"""Database-backed notification events.

These SQLAlchemy hooks keep important domain-state changes synchronized with the
in-app notification center and FCM delivery. Domain writes remain the source of
truth; push delivery is best-effort and never rolls back a successful database
transaction.
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import event, inspect, select
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.core.models import (
    DeviceToken,
    InvitationStatusEnum,
    Notification,
    Registration,
    RegistrationStatusEnum,
    RewardAdEvent,
    Team,
    TeamInvitation,
    TeamMember,
    Tournament,
    TournamentStatusEnum,
    User,
)
from app.notifications.fcm_service import send_push

_PENDING_KEY = "_notification_pushes"


def _queue_notification(session: Session, *, user_id: str, title: str, body: str, notification_type: str, data: dict[str, str]) -> None:
    notification = Notification(
        id=str(uuid4()),
        user_id=user_id,
        title=title,
        body=body,
        notification_type=notification_type,
        data=data,
        read_at=None,
    )
    session.add(notification)

    with session.no_autoflush:
        tokens = [
            row[0]
            for row in session.execute(
                select(DeviceToken.token).where(
                    DeviceToken.user_id == user_id,
                    DeviceToken.is_active.is_(True),
                )
            ).all()
        ]

    session.info.setdefault(_PENDING_KEY, []).append(
        (
            tokens,
            title,
            body,
            {"notification_id": notification.id, "type": notification_type, **data},
        )
    )


def _team_name(session: Session, team_id: str) -> str:
    with session.no_autoflush:
        team = session.get(Team, team_id)
    return team.name if team else "the team"


def _team_member_ids(session: Session, team_id: str) -> list[str]:
    with session.no_autoflush:
        rows = session.execute(
            select(TeamMember.user_id).where(TeamMember.team_id == team_id)
        ).all()
    return [str(row[0]) for row in rows if row[0]]


def _queue_tournament_users(session: Session, *, tournament: Tournament, title: str, body: str, notification_type: str) -> None:
    with session.no_autoflush:
        user_ids = [
            str(row[0])
            for row in session.execute(select(User.id).where(User.is_active.is_(True))).all()
        ]

    for user_id in user_ids:
        _queue_notification(
            session,
            user_id=user_id,
            title=title,
            body=body,
            notification_type=notification_type,
            data={"tournament_id": tournament.id},
        )


def _queue_registration_users(session: Session, *, registration: Registration, title: str, body: str, notification_type: str) -> None:
    for user_id in _team_member_ids(session, registration.team_id):
        _queue_notification(
            session,
            user_id=user_id,
            title=title,
            body=body,
            notification_type=notification_type,
            data={
                "registration_id": registration.id,
                "tournament_id": registration.tournament_id,
                "team_id": registration.team_id,
                "slot": str(registration.slot or ""),
            },
        )


@event.listens_for(Session, "before_flush")
def _notification_events(session: Session, flush_context, instances) -> None:
    # Team invitations
    for obj in list(session.new):
        if isinstance(obj, TeamInvitation):
            name = _team_name(session, obj.team_id)
            _queue_notification(
                session,
                user_id=obj.receiver_id,
                title="New Team Invitation",
                body=f"You have been invited to join {name}.",
                notification_type="team_invitation",
                data={"invitation_id": obj.id, "team_id": obj.team_id},
            )

    for obj in list(session.dirty):
        if not isinstance(obj, TeamInvitation):
            continue
        history = inspect(obj).attrs.status.history
        if not history.has_changes():
            continue

        name = _team_name(session, obj.team_id)
        status = obj.status
        if status == InvitationStatusEnum.accepted:
            _queue_notification(session, user_id=obj.sender_id, title="Team Invitation Accepted", body=f"Your invitation to {name} was accepted.", notification_type="team_invitation_accepted", data={"invitation_id": obj.id, "team_id": obj.team_id})
        elif status == InvitationStatusEnum.rejected:
            _queue_notification(session, user_id=obj.sender_id, title="Team Invitation Rejected", body=f"Your invitation to {name} was rejected.", notification_type="team_invitation_rejected", data={"invitation_id": obj.id, "team_id": obj.team_id})
        elif status == InvitationStatusEnum.cancelled:
            _queue_notification(session, user_id=obj.receiver_id, title="Team Invitation Cancelled", body=f"The invitation to join {name} was cancelled.", notification_type="team_invitation_cancelled", data={"invitation_id": obj.id, "team_id": obj.team_id})
        elif status == InvitationStatusEnum.expired:
            _queue_notification(session, user_id=obj.receiver_id, title="Team Invitation Expired", body=f"Your invitation to join {name} has expired.", notification_type="team_invitation_expired", data={"invitation_id": obj.id, "team_id": obj.team_id})

    # Registration lifecycle
    for obj in list(session.new):
        if isinstance(obj, Registration):
            _queue_notification(
                session,
                user_id=obj.captain_id,
                title="Registration Started",
                body="Your tournament registration has been created. Complete the required ads to finish registration.",
                notification_type="registration_pending",
                data={"registration_id": obj.id, "tournament_id": obj.tournament_id, "team_id": obj.team_id},
            )

    reward_registration_ids = {
        str(obj.registration_id) for obj in session.new if isinstance(obj, RewardAdEvent)
    }

    for obj in list(session.dirty):
        if not isinstance(obj, Registration):
            continue
        history = inspect(obj).attrs.status.history
        if not history.has_changes():
            continue

        status = obj.status
        if status == RegistrationStatusEnum.registered and obj.id not in reward_registration_ids:
            _queue_registration_users(
                session,
                registration=obj,
                title="Tournament Registration Approved",
                body=f"Your team registration was approved. Slot #{obj.slot} has been assigned.",
                notification_type="registration_registered",
            )
        elif status == RegistrationStatusEnum.rejected:
            _queue_registration_users(
                session,
                registration=obj,
                title="Tournament Registration Rejected",
                body="Your tournament registration was rejected by the admin.",
                notification_type="registration_rejected",
            )
        elif status == RegistrationStatusEnum.ad_verification:
            _queue_notification(
                session,
                user_id=obj.captain_id,
                title="Ad Verification Started",
                body="Your registration is now waiting for rewarded-ad verification.",
                notification_type="registration_ad_verification",
                data={"registration_id": obj.id, "tournament_id": obj.tournament_id, "team_id": obj.team_id},
            )

    # Tournament lifecycle
    for obj in list(session.dirty):
        if not isinstance(obj, Tournament):
            continue
        history = inspect(obj).attrs.status.history
        if not history.has_changes():
            continue

        status = obj.status
        if status == TournamentStatusEnum.published:
            _queue_tournament_users(
                session,
                tournament=obj,
                title="New Tournament Published",
                body=f"{obj.name} is now open for registration.",
                notification_type="tournament_published",
            )
        elif status == TournamentStatusEnum.closed:
            with session.no_autoflush:
                registrations = session.execute(
                    select(Registration).where(Registration.tournament_id == obj.id)
                ).scalars().all()
            for registration in registrations:
                _queue_registration_users(
                    session,
                    registration=registration,
                    title="Tournament Closed",
                    body=f"{obj.name} is now closed.",
                    notification_type="tournament_closed",
                )


@event.listens_for(Session, "after_commit")
def _deliver_queued_pushes(session: Session) -> None:
    queued = session.info.pop(_PENDING_KEY, [])
    invalid_tokens: set[str] = set()

    for tokens, title, body, data in queued:
        if tokens:
            invalid_tokens.update(send_push(tokens, title, body, data=data))

    if not invalid_tokens:
        return

    # after_commit is outside the original transaction. Use a short-lived
    # independent session so invalid FCM registrations are deactivated without
    # touching the already-committed domain transaction.
    cleanup_db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        (
            cleanup_db.query(DeviceToken)
            .filter(DeviceToken.token.in_(invalid_tokens))
            .update(
                {DeviceToken.is_active: False, DeviceToken.updated_at: now},
                synchronize_session=False,
            )
        )
        cleanup_db.commit()
    except Exception:
        cleanup_db.rollback()
    finally:
        cleanup_db.close()


@event.listens_for(Session, "after_rollback")
def _clear_queued_pushes(session: Session) -> None:
    session.info.pop(_PENDING_KEY, None)
