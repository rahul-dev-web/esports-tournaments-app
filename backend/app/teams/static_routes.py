"""Static team routes that must be registered before dynamic /{team_id} routes.

FastAPI evaluates path operations in declaration order. The main team router
contains dynamic paths such as /{team_id}/members, so static two-segment paths
like /user/my-teams and /invitations/received must be registered first.

The handlers below delegate to the existing implementation so business logic
remains in one place.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.common.deps import current_user_id
from app.core.database import get_db
from app.teams.router import get_my_teams, get_received_invitations

router = APIRouter()


@router.get("/user/my-teams", response_model=list, tags=["teams"])
async def static_get_my_teams(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """Resolve the static my-teams path before /{team_id}/... routes."""
    return await get_my_teams(user_id=user_id, db=db)


@router.get("/invitations/received", response_model=list, tags=["teams"])
async def static_get_received_invitations(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """Resolve the static received-invitations path before dynamic routes."""
    return await get_received_invitations(user_id=user_id, db=db)
