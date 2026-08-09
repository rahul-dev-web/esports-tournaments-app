"""
User endpoints
- Profile management
- User operations
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.models import User
from app.common.models import UserProfile, UserProfileUpdate
from app.common.deps import current_user_id
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

@router.get("/me", response_model=UserProfile, tags=["users"])
async def get_current_user(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
):
    """Get current user's profile"""
    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return UserProfile.from_orm(user)

@router.patch("/me", response_model=UserProfile, tags=["users"])
async def update_current_user(
    payload: UserProfileUpdate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
):
    """Update current user's profile"""
    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Update only provided fields
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)

    db.commit()
    db.refresh(user)

    logger.info(f"User {user_id} profile updated")
    return UserProfile.from_orm(user)

@router.get("/{user_id}", response_model=UserProfile, tags=["users"])
async def get_user(
    user_id: str,
    db: Session = Depends(get_db)
):
    """Get any user's public profile"""
    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return UserProfile.from_orm(user)

@router.get("", response_model=list[UserProfile], tags=["users"])
async def list_users(
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """List all users with pagination"""
    users = db.query(User).offset(skip).limit(limit).all()
    return [UserProfile.from_orm(u) for u in users]
