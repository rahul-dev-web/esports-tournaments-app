from fastapi import APIRouter, Depends
from ..common.deps import current_user_id
from ..common.models import UserProfile, UserProfileUpdate
from ..store import store

router = APIRouter()

@router.get("/me", response_model=UserProfile)
async def get_me(user_id: str = Depends(current_user_id)):
    return store.users.setdefault(user_id, UserProfile(id=user_id, email=f"{user_id}@example.com", name="Player", username=f"player_{user_id[:6]}"))

@router.patch("/me", response_model=UserProfile)
async def update_me(payload: UserProfileUpdate, user_id: str = Depends(current_user_id)):
    profile = await get_me(user_id)
    for key, value in payload.model_dump(exclude_none=True).items():
        setattr(profile, key, value)
    return profile
