"""FastAPI authentication and authorization dependencies."""

from __future__ import annotations

import logging
import re
import time
from threading import Lock
from typing import Any

import httpx
from fastapi import Depends, Header, HTTPException
from jose import JWTError, jwk, jwt
from sqlalchemy.orm import Session

from app.common.config import settings
from app.core.database import get_db
from app.core.models import RoleEnum, User


_JWKS_CACHE: dict[str, Any] | None = None
_JWKS_CACHE_TIME = 0.0
_JWKS_CACHE_TTL = 600
_JWKS_LOCK = Lock()
logger = logging.getLogger(__name__)


def _supabase_jwks_url() -> str:
    base_url = settings.SUPABASE_URL.rstrip("/")
    if not base_url:
        raise HTTPException(status_code=503, detail="SUPABASE_URL is not configured")
    return f"{base_url}/auth/v1/.well-known/jwks.json"


def _get_supabase_jwks(force_refresh: bool = False) -> dict[str, Any]:
    global _JWKS_CACHE, _JWKS_CACHE_TIME
    now = time.time()
    if not force_refresh and _JWKS_CACHE is not None and now - _JWKS_CACHE_TIME < _JWKS_CACHE_TTL:
        return _JWKS_CACHE
    with _JWKS_LOCK:
        now = time.time()
        if not force_refresh and _JWKS_CACHE is not None and now - _JWKS_CACHE_TIME < _JWKS_CACHE_TTL:
            return _JWKS_CACHE
        try:
            with httpx.Client(timeout=5.0) as client:
                response = client.get(_supabase_jwks_url())
                response.raise_for_status()
            data = response.json()
            if not isinstance(data, dict) or not isinstance(data.get("keys"), list):
                raise ValueError("Invalid JWKS response")
            _JWKS_CACHE = data
            _JWKS_CACHE_TIME = time.time()
            return data
        except Exception as exc:
            logger.exception("Unable to fetch Supabase JWKS: %s", exc)
            raise HTTPException(status_code=503, detail="Unable to load Supabase JWT signing keys") from exc


def _find_jwks_key(kid: str, force_refresh: bool = False) -> dict[str, Any] | None:
    jwks = _get_supabase_jwks(force_refresh=force_refresh)
    for key in jwks.get("keys", []):
        if isinstance(key, dict) and key.get("kid") == kid:
            return key
    return None


def _slugify_username(seed: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_]+", "_", seed.lower()).strip("_")
    cleaned = re.sub(r"_+", "_", cleaned)
    if not cleaned:
        cleaned = "player"
    if not cleaned[0].isalpha():
        cleaned = f"user_{cleaned}"
    return cleaned[:20]


def _parse_dev_token(token: str) -> dict[str, Any]:
    parts = token.removeprefix("dev:").split("|")
    sub = parts[0].strip() if parts else ""
    email = parts[1].strip() if len(parts) > 1 else ""
    name = parts[2].strip() if len(parts) > 2 else ""
    if not sub:
        raise HTTPException(status_code=401, detail="Development token is missing a user id")
    return {"sub": sub, "email": email or f"{sub}@example.local", "name": name or sub, "role": "authenticated", "user_metadata": {}}


def _decode_supabase_token(token: str) -> dict[str, Any]:
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid authentication token") from exc

    algorithm = str(header.get("alg") or "")
    kid = str(header.get("kid") or "")

    if algorithm == "ES256":
        if not kid:
            raise HTTPException(status_code=401, detail="Authentication token is missing signing key id")
        key_data = _find_jwks_key(kid)
        if key_data is None:
            key_data = _find_jwks_key(kid, force_refresh=True)
        if key_data is None:
            raise HTTPException(status_code=401, detail="JWT signing key was not found")
        try:
            public_key = jwk.construct(key_data, algorithm="ES256")
            issuer = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1"
            return jwt.decode(token, public_key, algorithms=["ES256"], issuer=issuer, options={"verify_aud": False})
        except JWTError as exc:
            logger.warning("Supabase ES256 JWT verification failed: %s", exc)
            raise HTTPException(status_code=401, detail="Invalid authentication token") from exc

    if algorithm == "HS256":
        if settings.SUPABASE_JWT_SECRET:
            try:
                issuer = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1" if settings.SUPABASE_URL else None
                decode_kwargs: dict[str, Any] = {"algorithms": ["HS256"], "options": {"verify_aud": False}}
                if issuer:
                    decode_kwargs["issuer"] = issuer
                return jwt.decode(token, settings.SUPABASE_JWT_SECRET, **decode_kwargs)
            except JWTError as exc:
                raise HTTPException(status_code=401, detail="Invalid authentication token") from exc
        if settings.ENVIRONMENT.lower() in {"development", "test"} and token.startswith("dev:"):
            return _parse_dev_token(token)
        raise HTTPException(status_code=503, detail="Authentication is not configured. Set SUPABASE_JWT_SECRET for legacy HS256 tokens or use a dev token in local development.")

    raise HTTPException(status_code=401, detail=f"Unsupported JWT signing algorithm: {algorithm}")


def _extract_profile_payload(claims: dict[str, Any]) -> tuple[str, str, str]:
    user_id = str(claims.get("sub") or "").strip()
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication token is missing a subject")
    email = str(claims.get("email") or "").strip()
    if not email:
        email = f"{user_id}@example.local"
    metadata = claims.get("user_metadata") or {}
    name = str(metadata.get("full_name") or metadata.get("name") or claims.get("name") or email.split("@", 1)[0]).strip() or "Player"
    return user_id, email, name


def _get_or_create_profile(db: Session, claims: dict[str, Any]) -> User:
    user_id, email, name = _extract_profile_payload(claims)
    admin_emails = {item.strip().lower() for item in settings.ADMIN_EMAILS if item and item.strip()}
    is_admin_email = email.lower() in admin_emails

    profile = db.query(User).filter(User.id == user_id).first()

    if profile:
        # Account suspension is an authentication-level decision, not merely
        # an admin/UI flag. A valid Supabase JWT must not bypass it.
        if not profile.is_active:
            raise HTTPException(status_code=403, detail="Account is suspended")

        if not profile.name:
            profile.name = name
        if not profile.email:
            profile.email = email
        if not profile.username:
            profile.username = _slugify_username(email.split("@", 1)[0])
        if is_admin_email and profile.role != RoleEnum.admin:
            profile.role = RoleEnum.admin
        db.commit()
        db.refresh(profile)
        return profile

    username_seed = claims.get("preferred_username") or (claims.get("user_metadata") or {}).get("username") or email.split("@", 1)[0] or user_id[:8]
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
    admin_emails = {email.strip().lower() for email in settings.ADMIN_EMAILS if email and email.strip()}
    if user.email.lower() not in admin_emails:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user.id
