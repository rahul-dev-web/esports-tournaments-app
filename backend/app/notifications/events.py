from __future__ import annotations

from uuid import uuid4

from sqlalchemy import event, inspect, select
from sqlalchemy.orm import Session

from app.core.models import DeviceToken, InvitationStatusEnum, Notification, Team, TeamInvitation
from app.notifications.fcm_service import send_push

_PENDING_KEY = "_notification_pushes"


def _queue_notification(
    session: Session,
    *,
    user_id: str,
    title: str,
    body: str,
    notification_type: str,
    data: dict[str, str],
) -> None:
    notification = Notification(
        id=str(uuid4()),
        user_id=user_id,
        title=title,
        body=body,
    )
    session.add(notification)

    # Read active tokens without triggering a nested flush. Push delivery is
    # deferred until after the transaction commits successfully.
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
            {
                "notification_id": notification.id,
                "type": notification_type,
                **data,
            },
        )
    )


@event.listens_for(Session, "before_flush")
def _team_invitation_notifications(session: Session, flush_context, instances) -> None:
    # New invitation -> notify receiver.
    for obj in list(session.new):
        if not isinstance(obj, TeamInvitation):
            continue

        team = session.get(Team, obj.team_id)
        team_name = team.name if team else "a team"
        _queue_notification(
            session,
            user_id=obj.receiver_id,
            title="New Team Invitation",
            body=f"You have been invited to join {team_name}.",
            notification_type="team_invitation",
            data={"invitation_id": obj.id, "team_id": obj.team_id},
        )

    # Status change -> notify the other participant.
    for obj in list(session.dirty):
        if not isinstance(obj, TeamInvitation):
            continue

        history = inspect(obj).attrs.status.history
        if not history.has_changes():
            continue

        status = obj.status
        team = session.get(Team, obj.team_id)
        team_name = team.name if team else "the team"

        if status == InvitationStatusEnum.accepted:
            _queue_notification(
                session,
                user_id=obj.sender_id,
                title="Team Invitation Accepted",
                body=f"Your invitation to {team_name} was accepted.",
                notification_type="team_invitation_accepted",
                data={"invitation_id": obj.id, "team_id": obj.team_id},
            )
        elif status == InvitationStatusEnum.rejected:
            _queue_notification(
                session,
                user_id=obj.sender_id,
                title="Team Invitation Rejected",
                body=f"Your invitation to {team_name} was rejected.",
                notification_type="team_invitation_rejected",
                data={"invitation_id": obj.id, "team_id": obj.team_id},
            )
        elif status == InvitationStatusEnum.cancelled:
            _queue_notification(
                session,
                user_id=obj.receiver_id,
                title="Team Invitation Cancelled",
                body=f"The invitation to join {team_name} was cancelled.",
                notification_type="team_invitation_cancelled",
                data={"invitation_id": obj.id, "team_id": obj.team_id},
            )
        elif status == InvitationStatusEnum.expired:
            _queue_notification(
                session,
                user_id=obj.receiver_id,
                title="Team Invitation Expired",
                body=f"Your invitation to join {team_name} has expired.",
                notification_type="team_invitation_expired",
                data={"invitation_id": obj.id, "team_id": obj.team_id},
            )


@event.listens_for(Session, "after_commit")
def _deliver_queued_pushes(session: Session) -> None:
    for tokens, title, body, data in session.info.pop(_PENDING_KEY, []):
        if tokens:
            send_push(tokens, title, body, data=data)


@event.listens_for(Session, "after_rollback")
def _clear_queued_pushes(session: Session) -> None:
    session.info.pop(_PENDING_KEY, None)
