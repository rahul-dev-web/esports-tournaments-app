"""
Team management endpoints
- Create, read, update, delete teams
- Team member management
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.models import Team, TeamMember, User
from app.common.models import Team as TeamSchema, TeamCreate
from app.common.deps import current_user_id
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("", response_model=TeamSchema, tags=["teams"])
async def create_team(
    payload: TeamCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
):
    """Create a new team"""
    # Check if team name already exists
    existing = db.query(Team).filter(Team.name == payload.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Team name already exists")

    # Create team
    team = Team(
        name=payload.name,
        game=payload.game,
        captain_id=user_id,
        is_private=payload.is_private,
        logo_url=payload.logo_url,
    )

    db.add(team)
    db.commit()
    db.refresh(team)

    # Add captain as member
    member = TeamMember(team_id=team.id, user_id=user_id)
    db.add(member)
    db.commit()

    logger.info(f"Team {team.id} created by {user_id}")
    return TeamSchema.from_orm(team)

@router.get("", response_model=list[TeamSchema], tags=["teams"])
async def list_teams(
    game: str = None,
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """List teams with optional filtering"""
    query = db.query(Team)

    if game:
        query = query.filter(Team.game == game)

    teams = query.offset(skip).limit(limit).all()
    return [TeamSchema.from_orm(t) for t in teams]

@router.get("/{team_id}", response_model=TeamSchema, tags=["teams"])
async def get_team(
    team_id: str,
    db: Session = Depends(get_db)
):
    """Get team details"""
    team = db.query(Team).filter(Team.id == team_id).first()

    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    return TeamSchema.from_orm(team)

@router.patch("/{team_id}", response_model=TeamSchema, tags=["teams"])
async def update_team(
    team_id: str,
    payload: TeamCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
):
    """Update team (captain only)"""
    team = db.query(Team).filter(Team.id == team_id).first()

    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can update team")

    team.name = payload.name
    team.game = payload.game
    team.is_private = payload.is_private
    team.logo_url = payload.logo_url

    db.commit()
    db.refresh(team)

    logger.info(f"Team {team_id} updated by {user_id}")
    return TeamSchema.from_orm(team)

@router.delete("/{team_id}", tags=["teams"])
async def delete_team(
    team_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
):
    """Delete team (captain only)"""
    team = db.query(Team).filter(Team.id == team_id).first()

    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can delete team")

    db.delete(team)
    db.commit()

    logger.info(f"Team {team_id} deleted")
    return {"success": True, "message": "Team deleted"}

@router.post("/{team_id}/members/{new_user_id}", tags=["teams"])
async def add_member(
    team_id: str,
    new_user_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
):
    """Add member to team"""
    team = db.query(Team).filter(Team.id == team_id).first()

    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    if team.is_private and team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Can't join private team")

    # Check if already member
    existing = db.query(TeamMember).filter(
        TeamMember.team_id == team_id,
        TeamMember.user_id == new_user_id
    ).first()

    if existing:
        raise HTTPException(status_code=400, detail="User already in team")

    member = TeamMember(team_id=team_id, user_id=new_user_id)
    db.add(member)
    db.commit()

    logger.info(f"User {new_user_id} added to team {team_id}")
    return {"success": True, "message": "Member added"}

@router.delete("/{team_id}/members/{member_user_id}", tags=["teams"])
async def remove_member(
    team_id: str,
    member_user_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db)
):
    """Remove member from team"""
    team = db.query(Team).filter(Team.id == team_id).first()

    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can remove members")

    member = db.query(TeamMember).filter(
        TeamMember.team_id == team_id,
        TeamMember.user_id == member_user_id
    ).first()

    if not member:
        raise HTTPException(status_code=404, detail="Member not in team")

    db.delete(member)
    db.commit()

    logger.info(f"User {member_user_id} removed from team {team_id}")
    return {"success": True, "message": "Member removed"}
