"""Application-level notification helpers.

Persists an in-app notification and best-effort delivers the same event through
FCM. Push delivery is intentionally non-blocking for the database notification.
"""

from __future__ import annotations

from datetime import datetime, timezone
from sqlalchemy.orm import Session

from app.core.models import DeviceToken, Notification
from app.notifications.fcm_service import send_push


def notify_user(
    db: Session,
    *,
    user_id: str,
    title: str,
    body: str,
    notification_type: str,
    data: dict[str, str] | None = None,
) -> Notification:
    """Create an in-app notification and best-effort FCM push for one user."""
    now = datetime.now(timezone.utc)
    normalized_data = {str(key): str(value) for key, value in (data or {}).items()}
    notification = Notification(
        user_id=user_id,
        title=title.strip(),
        body=body.strip(),
        notification_type=notification_type.strip() or "general",
        data=normalized_data,
        read_at=None,
        created_at=now,
        updated_at=now,
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)

    tokens = [
        item.token
        for item in db.query(DeviceToken)
        .filter(DeviceToken.user_id == user_id, DeviceToken.is_active.is_(True))
        .all()
    ]
    push_data = {
        "notification_id": notification.id,
        "type": notification.notification_type,
        **normalized_data,
    }
    if tokens:
        send_push(tokens, notification.title, notification.body, data=push_data)

    return notification


def notify_users(
    db: Session,
    *,
    user_ids: list[str],
    title: str,
    body: str,
    notification_type: str,
    data: dict[str, str] | None = None,
) -> None:
    """Notify multiple users, ignoring duplicate user IDs."""
    for user_id in dict.fromkeys(user_ids):
        notify_user(
            db,
            user_id=user_id,
            title=title,
            body=body,
            notification_type=notification_type,
            data=data,
        )
