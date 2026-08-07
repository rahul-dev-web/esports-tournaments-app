from fastapi import APIRouter, Depends
from ..common.deps import admin_user_id
from ..store import store

router = APIRouter()

@router.get("/dashboard")
async def dashboard(_: str = Depends(admin_user_id)):
    return {"total_users": len(store.users), "total_teams": len(store.teams), "total_registrations": len(store.registrations), "active_tournaments": sum(t.status.value == "published" for t in store.tournaments.values())}
