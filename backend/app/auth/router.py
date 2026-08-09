from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.common.deps import current_user_id
from ..common.models import UserProfile
from app.core.database import get_db
from app.core.models import User

router = APIRouter()

@router.post("/google", response_model=UserProfile)
async def google_login(user_id: str | None = None, db: Session = Depends(get_db), authenticated_user_id: str = Depends(current_user_id)):
    """Client verifies Google with Supabase Auth, then calls this profile bootstrap endpoint."""
    user_id = user_id or authenticated_user_id
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        user = User(id=user_id, email=f"{user_id}@example.com", name="New Player", username=f"player_{user_id[:6]}")
        db.add(user)
        db.commit()
        db.refresh(user)
    return user
