"""Authentication bootstrap endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.common.deps import current_user
from app.core.database import get_db
from app.core.models import User
from app.users.schemas import UserProfileResponse


router = APIRouter()


@router.get("/me", response_model=UserProfileResponse)
async def me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    profile = db.query(User).filter(User.id == user.id).first()
    return UserProfileResponse.model_validate(profile or user)


@router.post("/google", response_model=UserProfileResponse)
async def google_login(user: User = Depends(current_user)):
    return UserProfileResponse.model_validate(user)
