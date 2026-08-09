"""
FastAPI dependencies
- Authentication
- Authorization
"""

from fastapi import Depends, HTTPException, Header
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.models import User, RoleEnum

import logging


logger = logging.getLogger(__name__)


async def current_user_id(
    authorization: str = Header(None),
    db: Session = Depends(get_db)
) -> str:
    """
    Get current user ID from request.

    For now:
    - If Authorization header is missing, use demo user.
    - Otherwise, extract the user ID from the Bearer token.

    TODO:
    Replace this temporary authentication with proper
    Supabase JWT verification in production.
    """

    if not authorization:
        # Demo mode
        if not db.query(User).filter(User.id == "demo-user").first():
            db.add(User(id="demo-user", email="demo-user@example.com", name="Demo Player", username="demo_user"))
            db.commit()
        return "demo-user"

    # Temporary authentication
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization must use Bearer token")
    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Bearer token is missing")
    return token


async def require_admin(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
) -> str:
    """
    Require the current user to have admin role.
    """

    user = db.query(User).filter(User.id == user_id).first()

    if not user or user.role != RoleEnum.admin:
        raise HTTPException(
            status_code=403,
            detail="Admin access required"
        )

    return user_id
