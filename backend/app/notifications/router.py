"""Notification and device-token endpoints."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.common.deps import current_user_id, require_admin
from app.common.models import DeviceTokenCreate, DeviceTokenResponse, NotificationResponse
from app.core.database import get_db
from app.core.models import DeviceToken, Notification


router = APIRouter()


@router.get("/me", response_model=list[NotificationResponse])
async def my_notifications(
    user_id: str = Depends(current_user_id),
    unread_only: bool = Query(False),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    query = db.query(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        query = query.filter(Notification.read_at.is_(None))
    return query.order_by(Notification.created_at.desc()).limit(limit).all()


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def mark_notification_read(
    notification_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    notification = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    if notification.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not allowed to update this notification")

    notification.read_at = datetime.now(timezone.utc)
    notification.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(notification)
    return notification


@router.post("/device-tokens", response_model=DeviceTokenResponse)
async def register_device_token(
    payload: DeviceTokenCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    token = payload.token.strip()
    if not token:
        raise HTTPException(status_code=422, detail="token is required")

    device_token = db.query(DeviceToken).filter(DeviceToken.token == token).first()
    if device_token and device_token.user_id != user_id:
        raise HTTPException(status_code=409, detail="Device token already registered for another user")

    if not device_token:
        device_token = DeviceToken(
            user_id=user_id,
            token=token,
            platform=payload.platform.strip().lower(),
            device_name=payload.device_name,
            is_active=True,
            last_seen_at=datetime.now(timezone.utc),
        )
        db.add(device_token)
    else:
        device_token.platform = payload.platform.strip().lower()
        device_token.device_name = payload.device_name
        device_token.is_active = True
        device_token.last_seen_at = datetime.now(timezone.utc)
        device_token.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(device_token)
    return device_token


@router.delete("/device-tokens/{token_id}")
async def deactivate_device_token(
    token_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    device_token = db.query(DeviceToken).filter(DeviceToken.id == token_id).first()
    if not device_token:
        raise HTTPException(status_code=404, detail="Device token not found")
    if device_token.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not allowed to deactivate this token")

    device_token.is_active = False
    device_token.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"success": True, "token_id": token_id}


@router.post("/admin/notify")
async def admin_notify(
    title: str,
    body: str,
    target_user_id: str,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    notification = Notification(
        user_id=target_user_id,
        title=title.strip(),
        body=body.strip(),
        read_at=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return {"success": True, "notification_id": notification.id}
