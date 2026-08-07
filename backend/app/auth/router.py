from fastapi import APIRouter
from ..common.deps import current_user_id
from ..common.models import UserProfile
from ..store import store

router = APIRouter()

@router.post("/google", response_model=UserProfile)
async def google_login(user_id: str = None):
    """Client verifies Google with Supabase Auth, then calls this profile bootstrap endpoint."""
    if not user_id:
        user_id = "demo-user"
    if user_id not in store.users:
        store.users[user_id] = UserProfile(id=user_id, email=f"{user_id}@example.com", name="New Player", username=f"player_{user_id[:6]}")
    return store.users[user_id]
