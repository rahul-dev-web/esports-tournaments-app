"""FastAPI authentication and authorization dependencies."""

from __future__ import annotations

import logging
import re
from typing import Any

from fastapi import Depends, Header, HTTPException
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.common.config import settings
from app.core.database import get_db
from app.core.models import RoleEnum, User


logger = logging.getLogger(__name__)


def _slugify_username(seed: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_]+", "_", seed.lower()).strip("_")
    cleaned = re.sub(r"_+", "_", cleaned)
    if not cleaned:
        cleaned = "player"
    if not cleaned[0].isalpha():
        cleaned = f"user_{cleaned}"
    return cleaned[:20]


def _parse_dev_token(token: str) -> dict[str, Any]:
    """Support explicit dev tokens when JWT material is not configured."""

    parts = token.removeprefix("dev:").split("|")
    sub = parts[0].strip() if parts else ""
    email = parts[1].strip() if len(parts) > 1 else ""
    name = parts[2].strip() if len(parts) > 2 else ""
    if not sub:
        raise HTTPException(status_code=401, detail="Development token is missing a user id")
    return {
        "sub": sub,
        "email": email or f"{sub}@example.local",
        "name": name or sub,
        "role": "authenticated",
        "user_metadata": {},
    }


def _decode_supabase_token(token: str) -> dict[str, Any]:
    if settings.SUPABASE_JWT_SECRET:
        try:
            return jwt.decode(
                token,
                settings.SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
        except JWTError as exc:
            raise HTTPException(status_code=401, detail="Invalid authentication token") from exc

    if settings.ENVIRONMENT.lower() in {"development", "test"} and token.startswith("dev:"):
        return _parse_dev_token(token)

    raise HTTPException(
        status_code=503,
        detail="Authentication is not configured. Set SUPABASE_JWT_SECRET or use a dev token in local development.",
    )


def _extract_profile_payload(claims: dict[str, Any]) -> tuple[str, str, str]:
    user_id = str(claims.get("sub") or "").strip()
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication token is missing a subject")

    email = str(claims.get("email") or "").strip()
    if not email:
        email = f"{user_id}@example.local"

    metadata = claims.get("user_metadata") or {}
    name = str(
        metadata.get("full_name")
        or metadata.get("name")
        or claims.get("name")
        or email.split("@", 1)[0]
    ).strip() or "Player"

    return user_id, email, name


def _get_or_create_profile(db: Session, claims: dict[str, Any]) -> User:
    user_id, email, name = _extract_profile_payload(claims)
    admin_emails = {item.lower() for item in settings.ADMIN_EMAILS if item}
    is_admin_email = email.lower() in admin_emails
    profile = db.query(User).filter(User.id == user_id).first()
    if profile:
        if not profile.name:
            profile.name = name
        if not profile.username:
            profile.username = _slugify_username(email.split("@", 1)[0])
        if is_admin_email and profile.role != RoleEnum.admin:
            profile.role = RoleEnum.admin
        db.commit()
        db.refresh(profile)
        return profile

    username_seed = (
        claims.get("preferred_username")
        or (claims.get("user_metadata") or {}).get("username")
        or email.split("@", 1)[0]
        or user_id[:8]
    )
    username = _slugify_username(str(username_seed))
    suffix = 1
    while db.query(User).filter(User.username == username).first():
        suffix += 1
        username = _slugify_username(f"{username_seed}_{suffix}")

    profile = User(
        id=user_id,
        email=email,
        name=name,
        username=username,
        role=RoleEnum.admin if is_admin_email else RoleEnum.user,
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


def current_user(authorization: str = Header(None), db: Session = Depends(get_db)) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization must use Bearer token")

    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Bearer token is missing")

    claims = _decode_supabase_token(token)
    return _get_or_create_profile(db, claims)


def current_user_id(user: User = Depends(current_user)) -> str:
    return user.id


def require_admin(user: User = Depends(current_user)) -> str:
    admin_emails = {email.lower() for email in settings.ADMIN_EMAILS if email}
    if user.email.lower() not in admin_emails:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user.id
