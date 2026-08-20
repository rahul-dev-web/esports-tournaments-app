"""Database-backed notification events.

Important domain notifications are created in the same database transaction as
 the domain change. FCM delivery happens only after a successful commit, so a
push/provider failure can never roll back or turn the domain operation into a
500 response.
"""

from __future__ import annotations

import logging
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

logger = logging.getLogger(__name__)
_PENDING_KEY = "_notification_pushes"


def _ensure_id(obj) -> str:
    """Materialize SQLAlchemy Python-side UUID defaults before notification data is built."""
    if not getattr(obj, "id", None):
        obj.id = str(uuid4())
    return str(obj.id)


def _queue_notification(
    session: Session,
    *,
    user_id: str,
    title: str,
    body: str,
    notification_type: str,
    data: dict[str, str],
) -> None:
    normalized_data = {str(key): str(value) for key, value in data.items() if value is not None}
    notification = Notification(
        id=str(uuid4()),
        user_id=str(user_id),
        title=title.strip(),
        body=body.strip(),
        notification_type=notification_type.strip() or "general",
        data=normalized_data,
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
            notification.title,
            notification.body,
            {
                "notification_id": notification.id,
                "type": notification.notification_type,
                **normalized_data,
            },
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


def _queue_tournament_users(
    session: Session,
    *,
    tournament: Tournament,
    title: str,
    body: str,
    notification_type: str,
) -> None:
    tournament_id = _ensure_id(tournament)
    with session.no_autoflush:
        user_ids = [
            str(row[0])
            for row in session.execute(
                select(User.id).where(User.is_active.is_(True))
            ).all()
        ]

    for user_id in user_ids:
        _queue_notification(
            session,
            user_id=user_id,
            title=title,
            body=body,
            notification_type=notification_type,
            data={"tournament_id": tournament_id},
        )


def _queue_registration_users(
    session: Session,
    *,
    registration: Registration,
    title: str,
    body: str,
    notification_type: str,
) -> None:
    registration_id = _ensure_id(registration)
    for user_id in _team_member_ids(session, registration.team_id):
        _queue_notification(
            session,
            user_id=user_id,
            title=title,
            body=body,
            notification_type=notification_type,
            data={
                "registration_id": registration_id,
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
            invitation_id = _ensure_id(obj)
            name = _team_name(session, obj.team_id)
            _queue_notification(
                session,
                user_id=obj.receiver_id,
                title="New Team Invitation",
                body=f"You have been invited to join {name}.",
                notification_type="team_invitation",
                data={"invitation_id": invitation_id, "team_id": obj.team_id},
            )

    # Registration creation
    for obj in list(session.new):
        if isinstance(obj, Registration):
            registration_id = _ensure_id(obj)
            _queue_notification(
                session,
                user_id=obj.captain_id,
                title="Registration Started",
                body="Your tournament registration has been created. Complete the required ads to finish registration.",
                notification_type="registration_pending",
                data={
                    "registration_id": registration_id,
                    "tournament_id": obj.tournament_id,
                    "team_id": obj.team_id,
                },
            )

    # Tournament creation. This replaces the old endpoint-level notification
    # call, so there is now exactly one notification source for tournament
    # publication events.
    for obj in list(session.new):
        if isinstance(obj, Tournament) and obj.status == TournamentStatusEnum.published:
            _queue_tournament_users(
                session,
                tournament=obj,
                title="New Tournament Published",
                body=f"{obj.name} is now open for registration.",
                notification_type="tournament_published",
            )

    reward_registration_ids = {
        str(obj.registration_id) for obj in session.new if isinstance(obj, RewardAdEvent)
    }

    # Registration lifecycle
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
                data={
                    "registration_id": _ensure_id(obj),
                    "tournament_id": obj.tournament_id,
                    "team_id": obj.team_id,
                },
            )

    # Tournament lifecycle updates
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
    if not queued:
        return

    invalid_tokens: set[str] = set()
    attempted = 0
    for tokens, title, body, data in queued:
        attempted += len(tokens)
        if tokens:
            invalid_tokens.update(send_push(tokens, title, body, data=data))

    logger.info(
        "Notification transaction committed: events=%d push_targets=%d invalid_tokens=%d",
        len(queued),
        attempted,
        len(invalid_tokens),
    )

    if not invalid_tokens:
        return

    # after_commit is outside the original transaction. Use an independent
    # session so token cleanup can never affect the already-committed domain
    # transaction.
    cleanup_db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        cleanup_db.query(DeviceToken).filter(
            DeviceToken.token.in_(invalid_tokens)
        ).update(
            {DeviceToken.is_active: False, DeviceToken.updated_at: now},
            synchronize_session=False,
        )
        cleanup_db.commit()
    except Exception:
        cleanup_db.rollback()
        logger.exception("Failed to deactivate invalid FCM tokens")
    finally:
        cleanup_db.close()


@event.listens_for(Session, "after_rollback")
def _clear_queued_pushes(session: Session) -> None:
    session.info.pop(_PENDING_KEY, None)
