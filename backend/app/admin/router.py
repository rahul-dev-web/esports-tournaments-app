"""
Admin API routes
All endpoints require admin authentication
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session
from typing import Any, Optional, cast
from datetime import datetime
from app.common.deps import require_admin, current_user, current_user_id
from app.core.database import get_db
from app.core.models import (
    User, Team, TeamMember, Tournament, Registration, Settings,
    TournamentStatusEnum, RegistrationStatusEnum, RoleEnum
)
from app.common.models import SettingCreate, SettingResponse
import logging
import csv
import io

logger = logging.getLogger(__name__)
router = APIRouter(tags=["admin"])


@router.get("/me")
async def admin_me(
    user: User = Depends(current_user),
    _: str = Depends(require_admin),
):
    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "username": user.username,
        "is_admin": True,
    }

# ============================================================================
# SETTINGS MANAGEMENT (Priority 1 - CRITICAL!)
# ============================================================================

def get_setting(db: Session, key: str, default: Any = None) -> Any:
    """Helper to get setting by key"""
    setting = db.query(Settings).filter(Settings.key == key).first()
    return cast(Any, setting.value) if setting is not None else default

@router.get("/settings")
async def get_all_settings(
    _: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Get all settings
    
    Returns:
        List of all settings
    
    Example:
        GET /api/admin/settings
    """
    settings = db.query(Settings).all()
    return [SettingResponse.from_orm(s) for s in settings]

@router.get("/settings/{key}")
async def get_setting_by_key(
    key: str,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Get specific setting by key
    
    Path Parameters:
        key: Setting key
    
    Example:
        GET /api/admin/settings/ads_per_registration
    """
    setting = db.query(Settings).filter(Settings.key == key).first()
    
    if not setting:
        raise HTTPException(status_code=404, detail=f"Setting '{key}' not found")
    
    return SettingResponse.from_orm(setting)

@router.patch("/settings/{key}")
async def update_setting(
    key: str,
    payload: SettingCreate,
    user_id: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Update or create setting
    
    Path Parameters:
        key: Setting key
    
    Request Body:
        value: New value
        description: Optional description
        type: Type of setting
    
    Example:
        PATCH /api/admin/settings/ads_per_registration
        {
          "value": "3",
          "type": "number",
          "description": "Number of ads required per registration"
        }
    """
    setting = db.query(Settings).filter(Settings.key == key).first()
    
    if not setting:
        # Create new setting
        setting = Settings(
            key=key,
            value=payload.value,
            description=payload.description,
            value_type=payload.value_type,
            updated_by=user_id,
            updated_at=datetime.utcnow()
        )
        db.add(setting)
    else:
        # Update existing
        setting.value = payload.value
        setting.description = payload.description or setting.description
        setting.value_type = payload.value_type
        setting.updated_by = user_id
        setting.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(setting)
    
    logger.info(f"Setting '{key}' updated by admin {user_id}")
    return SettingResponse.from_orm(setting)

# ============================================================================
# DASHBOARD
# ============================================================================

@router.get("/dashboard")
async def dashboard(_: str = Depends(require_admin), db: Session = Depends(get_db)):
    """
    Get dashboard statistics
    
    Returns:
        Stats about users, teams, registrations, tournaments
    
    Example:
        GET /api/admin/dashboard
    """
    total_users = db.query(func.count(User.id)).scalar() or 0
    total_teams = db.query(func.count(Team.id)).scalar() or 0
    total_registrations = db.query(func.count(Registration.id)).scalar() or 0
    active_tournaments = db.query(func.count(Tournament.id)).filter(
        Tournament.status == TournamentStatusEnum.published
    ).scalar() or 0
    
    pending_registrations = db.query(func.count(Registration.id)).filter(
        Registration.status == RegistrationStatusEnum.pending
    ).scalar() or 0
    
    return {
        "total_users": total_users,
        "total_teams": total_teams,
        "total_registrations": total_registrations,
        "active_tournaments": active_tournaments,
        "pending_registrations": pending_registrations
    }

# ============================================================================
# USER MANAGEMENT
# ============================================================================

@router.get("/users")
async def list_users(
    skip: int = 0,
    limit: int = 10,
    role: Optional[str] = None,
    search: Optional[str] = None,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    List all users
    
    Query Parameters:
        skip: Pagination offset
        limit: Items per page
        role: Filter by role (user/admin)
        search: Search by name, username, email
    
    Example:
        GET /api/admin/users?skip=0&limit=10&role=user&search=john
    """
    query = db.query(User)
    
    if role:
        query = query.filter(User.role == role)
    
    if search:
        query = query.filter(
            (User.name.ilike(f"%{search}%")) |
            (User.username.ilike(f"%{search}%")) |
            (User.email.ilike(f"%{search}%"))
        )
    
    total = query.count()
    users = query.offset(skip).limit(limit).all()
    
    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "users": [{
            "id": u.id,
            "name": u.name,
            "username": u.username,
            "email": u.email,
            "role": u.role,
            "is_active": u.is_active,
            "created_at": u.created_at
        } for u in users]
    }

@router.patch("/users/{user_id}/suspend")
async def suspend_user(
    user_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Suspend user account
    
    Path Parameters:
        user_id: User ID to suspend
    
    Example:
        PATCH /api/admin/users/user-123/suspend
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user.is_active = False
    db.commit()
    
    logger.info(f"User {user_id} suspended by admin {admin_id}")
    return {"message": "User suspended", "user_id": user_id}

@router.patch("/users/{user_id}/unsuspend")
async def unsuspend_user(
    user_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Unsuspend user account
    
    Path Parameters:
        user_id: User ID to unsuspend
    
    Example:
        PATCH /api/admin/users/user-123/unsuspend
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user.is_active = True
    db.commit()
    
    logger.info(f"User {user_id} unsuspended by admin {admin_id}")
    return {"message": "User unsuspended", "user_id": user_id}

# ============================================================================
# REGISTRATION MANAGEMENT
# ============================================================================

@router.get("/registrations")
async def list_registrations(
    skip: int = 0,
    limit: int = 10,
    status: Optional[str] = None,
    tournament_id: Optional[str] = None,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    List all registrations
    
    Query Parameters:
        skip: Pagination offset
        limit: Items per page
        status: Filter by status (pending, ad_verification, registered, rejected)
        tournament_id: Filter by tournament
    
    Example:
        GET /api/admin/registrations?status=pending&tournament_id=tour-123
    """
    query = db.query(Registration)
    
    if status:
        query = query.filter(Registration.status == status)
    
    if tournament_id:
        query = query.filter(Registration.tournament_id == tournament_id)
    
    total = query.count()
    registrations = query.offset(skip).limit(limit).all()
    
    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "registrations": [{
            "id": r.id,
            "tournament_id": r.tournament_id,
            "team_id": r.team_id,
            "status": r.status,
            "ads_required": r.ads_required,
            "ads_completed": r.ads_completed,
            "slot": r.slot_number,
            "created_at": r.created_at
        } for r in registrations]
    }

@router.patch("/registrations/{registration_id}/approve")
async def approve_registration(
    registration_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Approve registration
    
    Path Parameters:
        registration_id: Registration ID
    
    Example:
        PATCH /api/admin/registrations/reg-123/approve
    """
    registration = db.query(Registration).filter(
        Registration.id == registration_id
    ).first()
    
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    
    registration.status = RegistrationStatusEnum.registered
    
    # Assign slot if not already assigned
    if not registration.slot_number:
        tournament = db.query(Tournament).filter(
            Tournament.id == registration.tournament_id
        ).first()
        
        if tournament:
            # Find next available slot
            max_slot = db.query(func.max(Registration.slot)).filter(
                Registration.tournament_id == tournament.id,
                Registration.slot.isnot(None)
            ).scalar() or 0
            
            registration.slot_number = max_slot + 1
            tournament.registered_teams = (tournament.registered_teams or 0) + 1
    
    db.commit()
    
    logger.info(f"Registration {registration_id} approved by admin {admin_id}")
    return {"message": "Registration approved", "registration_id": registration_id}

@router.patch("/registrations/{registration_id}/reject")
async def reject_registration(
    registration_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Reject registration
    
    Path Parameters:
        registration_id: Registration ID
    
    Example:
        PATCH /api/admin/registrations/reg-123/reject
    """
    registration = db.query(Registration).filter(
        Registration.id == registration_id
    ).first()
    
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
    
    registration.status = RegistrationStatusEnum.rejected
    db.commit()
    
    logger.info(f"Registration {registration_id} rejected by admin {admin_id}")
    return {"message": "Registration rejected", "registration_id": registration_id}

@router.get("/registrations/export")
async def export_registrations(
    tournament_id: Optional[str] = None,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Export registrations as CSV
    
    Query Parameters:
        tournament_id: Optional - export only for specific tournament
    
    Example:
        GET /api/admin/registrations/export?tournament_id=tour-123
    
    Returns:
        CSV content
    """
    query = db.query(Registration).join(Tournament).join(Team).join(User)
    
    if tournament_id:
        query = query.filter(Registration.tournament_id == tournament_id)
    
    registrations = query.all()
    
    # Create CSV
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Headers
    writer.writerow([
        "Registration ID", "Tournament", "Team", "Captain",
        "Status", "Ads Required", "Ads Completed", "Slot", "Created At"
    ])
    
    # Data
    for reg in registrations:
        tournament = db.query(Tournament).filter(Tournament.id == reg.tournament_id).first()
        team = db.query(Team).filter(Team.id == reg.team_id).first()
        captain = None
        if team:
            captain = db.query(User).filter(User.id == team.captain_id).first()
        
        writer.writerow([
            reg.id,
            tournament.name if tournament else "",
            team.name if team else "",
            captain.name if captain else "",
            reg.status,
            reg.ads_required,
            reg.ads_completed,
            reg.slot_number or "",
            reg.created_at
        ])
    
    csv_content = output.getvalue()
    logger.info(f"Exported {len(registrations)} registrations")
    
    return {
        "content_type": "text/csv",
        "filename": f"registrations_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
        "content": csv_content
    }

# ============================================================================
# TOURNAMENT MANAGEMENT (Enhanced)
# ============================================================================

@router.patch("/tournaments/{tournament_id}/status/{new_status}")
async def change_tournament_status(
    tournament_id: str,
    new_status: TournamentStatusEnum,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Change tournament status
    
    Path Parameters:
        tournament_id: Tournament ID
        new_status: draft, published, or closed
    
    Example:
        PATCH /api/admin/tournaments/tour-123/status/published
    """
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")
    
    tournament.status = new_status
    db.commit()
    
    logger.info(f"Tournament {tournament_id} status changed to {new_status} by admin {admin_id}")
    return {"message": "Tournament status updated", "tournament_id": tournament_id, "status": new_status}

@router.patch("/tournaments/{tournament_id}/config")
async def update_tournament_config(
    tournament_id: str,
    payload: dict,  # {"ads_required": 3, "policy": "captain_ads"}
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Update tournament configuration
    
    Path Parameters:
        tournament_id: Tournament ID
    
    Request Body:
        ads_required: Number of ads required
        policy: individual_ads or captain_ads
    
    Example:
        PATCH /api/admin/tournaments/tour-123/config
        {
          "ads_required": 3,
          "policy": "captain_ads"
        }
    """
    tournament = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")
    
    if "ads_required" in payload:
        tournament.ads_required = payload["ads_required"]
    
    if "policy" in payload:
        tournament.policy = payload["policy"]
    
    db.commit()
    
    logger.info(f"Tournament {tournament_id} config updated by admin {admin_id}")
    return {"message": "Tournament configuration updated", "tournament_id": tournament_id}

# ============================================================================
# TEAM MANAGEMENT
# ============================================================================

@router.get("/teams")
async def list_teams(
    skip: int = 0,
    limit: int = 10,
    game: Optional[str] = None,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    List all teams
    
    Query Parameters:
        skip: Pagination offset
        limit: Items per page
        game: Filter by game
    
    Example:
        GET /api/admin/teams?game=CS:GO
    """
    query = db.query(Team)
    
    if game:
        query = query.filter(Team.game == game)
    
    total = query.count()
    teams = query.offset(skip).limit(limit).all()
    
    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "teams": [{
            "id": t.id,
            "name": t.name,
            "game": t.game,
            "captain_id": t.captain_id,
            "is_private": t.is_private,
            "member_count": len(t.members) if t.members else 0,
            "created_at": t.created_at
        } for t in teams]
    }

@router.get("/teams/{team_id}")
async def get_team_details(
    team_id: str,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """
    Get team details with members and registrations
    
    Path Parameters:
        team_id: Team ID
    
    Example:
        GET /api/admin/teams/team-123
    """
    team = db.query(Team).filter(Team.id == team_id).first()
    
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    
    members = db.query(User).join(TeamMember).filter(TeamMember.team_id == team_id).all()
    registrations = db.query(Registration).filter(Registration.team_id == team_id).all()
    
    return {
        "id": team.id,
        "name": team.name,
        "game": team.game,
        "captain_id": team.captain_id,
        "is_private": team.is_private,
        "logo_url": team.logo_url,
        "created_at": team.created_at,
        "members": [{
            "id": m.id,
            "name": m.name,
            "username": m.username,
            "email": m.email
        } for m in members],
        "registrations": [{
            "id": r.id,
            "tournament_id": r.tournament_id,
            "status": r.status,
            "ads_completed": r.ads_completed
        } for r in registrations]
    }
