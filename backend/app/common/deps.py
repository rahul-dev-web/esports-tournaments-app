from fastapi import Header, HTTPException
from .config import get_settings


async def current_user_id(x_user_id: str | None = Header(default=None)) -> str:
    """Temporary dev auth boundary; replace with Supabase JWT verification in production."""
    if not x_user_id:
        raise HTTPException(401, "X-User-Id header is required")
    return x_user_id


async def admin_user_id(user_id: str = Header(alias="X-User-Id")) -> str:
    settings = get_settings()
    if not user_id or (settings.admins and user_id.lower() not in settings.admins):
        raise HTTPException(403, "Admin access required")
    return user_id
