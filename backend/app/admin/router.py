from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.common.deps import require_admin
from app.core.database import get_db
from app.core.models import User, Team, Tournament, Registration, TournamentStatusEnum

router = APIRouter()

@router.get("/dashboard")
async def dashboard(_: str = Depends(require_admin), db: Session = Depends(get_db)):
    return {
        "total_users": db.query(User).count(),
        "total_teams": db.query(Team).count(),
        "total_registrations": db.query(Registration).count(),
        "active_tournaments": db.query(Tournament).filter(Tournament.status == TournamentStatusEnum.published).count(),
    }
