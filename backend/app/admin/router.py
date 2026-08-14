"""
Admin API routes
All endpoints require admin authentication.
"""

from datetime import datetime
from typing import Any, Optional, cast

import csv
import io
import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.common.deps import require_admin, current_user
from app.common.models import SettingCreate, SettingResponse
from app.core.database import get_db
from app.core.models import (
    User,
    Team,
    TeamMember,
    Tournament,
    Registration,
    Settings,
    TournamentStatusEnum,
    RegistrationStatusEnum,
)


logger = logging.getLogger(__name__)

router = APIRouter(tags=["admin"])


# ============================================================================
# ADMIN USER UPDATE SCHEMA
# ============================================================================

class AdminUserUpdate(BaseModel):
    """
    Fields that an administrator is allowed to edit on a user's profile.

    Deliberately excludes:
    - email
    - role
    - is_active

    Email and role are not editable through this endpoint.
    Account suspension is handled separately by the suspend/unsuspend routes.
    """

    model_config = ConfigDict(extra="forbid")

    name: Optional[str] = None
    username: Optional[str] = None
    bio: Optional[str] = None
    country: Optional[str] = None
    state: Optional[str] = None
    city: Optional[str] = None
    photo_url: Optional[str] = None
    social_links: Optional[dict[str, Any]] = None
    preferred_game: Optional[str] = None
    in_game_uid: Optional[str] = None


# ============================================================================
# ADMIN PROFILE
# ============================================================================

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
# SETTINGS MANAGEMENT
# ============================================================================

def get_setting(db: Session, key: str, default: Any = None) -> Any:
    """Helper to get setting by key."""
    setting = db.query(Settings).filter(Settings.key == key).first()
    return cast(Any, setting.value) if setting is not None else default


@router.get("/settings")
async def get_all_settings(
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Get all settings.

    GET /api/admin/settings
    """
    settings = db.query(Settings).all()
    return [SettingResponse.from_orm(s) for s in settings]


@router.get("/settings/{key}")
async def get_setting_by_key(
    key: str,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Get a specific setting by key.

    GET /api/admin/settings/{key}
    """
    setting = db.query(Settings).filter(Settings.key == key).first()

    if not setting:
        raise HTTPException(
            status_code=404,
            detail=f"Setting '{key}' not found",
        )

    return SettingResponse.from_orm(setting)


@router.patch("/settings/{key}")
async def update_setting(
    key: str,
    payload: SettingCreate,
    user_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Update or create a setting.

    PATCH /api/admin/settings/{key}
    """
    setting = db.query(Settings).filter(Settings.key == key).first()

    if not setting:
        setting = Settings(
            key=key,
            value=payload.value,
            description=payload.description,
            value_type=payload.value_type,
            updated_by=user_id,
            updated_at=datetime.utcnow(),
        )
        db.add(setting)
    else:
        setting.value = payload.value
        setting.description = payload.description or setting.description
        setting.value_type = payload.value_type
        setting.updated_by = user_id
        setting.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(setting)

    logger.info(
        "Setting '%s' updated by admin %s",
        key,
        user_id,
    )

    return SettingResponse.from_orm(setting)


# ============================================================================
# DASHBOARD
# ============================================================================

@router.get("/dashboard")
async def dashboard(
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Get dashboard statistics and recent platform activities.

    GET /api/admin/dashboard

    Dashboard statistics:
    - total_users
    - total_teams
    - total_registrations
    - active_tournaments
    - pending_registrations

    Recent activities are generated from real database records:
    - profiles.created_at
    - teams.created_at
    - tournaments.created_at
    - tournament_registrations.created_at

    The latest 5 activities are returned in descending chronological order.
    """

    total_users = db.query(func.count(User.id)).scalar() or 0

    total_teams = db.query(func.count(Team.id)).scalar() or 0

    total_registrations = (
        db.query(func.count(Registration.id)).scalar() or 0
    )

    active_tournaments = (
        db.query(func.count(Tournament.id))
        .filter(
            Tournament.status == TournamentStatusEnum.published
        )
        .scalar()
        or 0
    )

    pending_registrations = (
        db.query(func.count(Registration.id))
        .filter(
            Registration.status == RegistrationStatusEnum.pending
        )
        .scalar()
        or 0
    )

    # ------------------------------------------------------------------------
    # RECENT ACTIVITIES
    #
    # Fetch a small recent window from each entity first, then combine the
    # results in Python. This avoids loading entire tables just to construct
    # the dashboard activity feed.
    # ------------------------------------------------------------------------

    recent_activities: list[dict[str, Any]] = []

    # ------------------------------------------------------------------------
    # Recent Users
    # ------------------------------------------------------------------------

    recent_users = (
        db.query(User)
        .order_by(User.created_at.desc())
        .limit(5)
        .all()
    )

    for user in recent_users:
        display_name = (
            user.name.strip()
            if user.name and user.name.strip()
            else user.username
        )

        if not display_name:
            display_name = user.email

        recent_activities.append(
            {
                "id": f"user:{user.id}",
                "type": "user",
                "title": "New User Joined",
                "description": display_name,
                "created_at": user.created_at,
            }
        )

    # ------------------------------------------------------------------------
    # Recent Teams
    # ------------------------------------------------------------------------

    recent_teams = (
        db.query(Team)
        .order_by(Team.created_at.desc())
        .limit(5)
        .all()
    )

    for team in recent_teams:
        recent_activities.append(
            {
                "id": f"team:{team.id}",
                "type": "team",
                "title": "Team Created",
                "description": team.name,
                "created_at": team.created_at,
            }
        )

    # ------------------------------------------------------------------------
    # Recent Tournaments
    # ------------------------------------------------------------------------

    recent_tournaments = (
        db.query(Tournament)
        .order_by(Tournament.created_at.desc())
        .limit(5)
        .all()
    )

    for tournament in recent_tournaments:
        recent_activities.append(
            {
                "id": f"tournament:{tournament.id}",
                "type": "tournament",
                "title": "New Tournament Created",
                "description": tournament.name,
                "created_at": tournament.created_at,
            }
        )

    # ------------------------------------------------------------------------
    # Recent Registrations
    #
    # Registration contains both team_id and tournament_id, so we explicitly
    # load the related names for a meaningful activity description.
    # ------------------------------------------------------------------------

    recent_registrations = (
        db.query(Registration, Team, Tournament)
        .join(
            Team,
            Team.id == Registration.team_id,
        )
        .join(
            Tournament,
            Tournament.id == Registration.tournament_id,
        )
        .order_by(Registration.created_at.desc())
        .limit(5)
        .all()
    )

    for registration, team, tournament in recent_registrations:
        team_name = team.name if team else "Unknown Team"
        tournament_name = (
            tournament.name
            if tournament
            else "Unknown Tournament"
        )

        recent_activities.append(
            {
                "id": f"registration:{registration.id}",
                "type": "registration",
                "title": "Team Registered",
                "description": (
                    f"{team_name} for {tournament_name}"
                ),
                "created_at": registration.created_at,
            }
        )

    # ------------------------------------------------------------------------
    # Combine all activity types, newest first, and keep only the latest 5.
    # ------------------------------------------------------------------------

    recent_activities.sort(
        key=lambda activity: activity["created_at"],
        reverse=True,
    )

    recent_activities = recent_activities[:5]

    return {
        "total_users": total_users,
        "total_teams": total_teams,
        "total_registrations": total_registrations,
        "active_tournaments": active_tournaments,
        "pending_registrations": pending_registrations,
        "recent_activities": recent_activities,
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
    db: Session = Depends(get_db),
):
    """
    List all users.

    GET /api/admin/users
    """

    query = db.query(User)

    if role:
        query = query.filter(User.role == role)

    if search:
        query = query.filter(
            (User.name.ilike(f"%{search}%"))
            | (User.username.ilike(f"%{search}%"))
            | (User.email.ilike(f"%{search}%"))
        )

    total = query.count()

    users = (
        query
        .offset(skip)
        .limit(limit)
        .all()
    )

    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "users": [
            {
                "id": user.id,
                "name": user.name,
                "username": user.username,
                "email": user.email,
                "role": user.role,
                "is_active": user.is_active,
                "created_at": user.created_at,
            }
            for user in users
        ],
    }


@router.get("/users/{user_id}")
async def get_user(
    user_id: str,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Get complete profile information for one user.

    GET /api/admin/users/{user_id}

    This endpoint intentionally exposes the user's email and role
    for administrative viewing, but those fields are not editable
    through the PATCH endpoint below.
    """

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "username": user.username,
        "bio": user.bio,
        "country": user.country,
        "state": user.state,
        "city": user.city,
        "photo_url": user.photo_url,
        "social_links": user.social_links,
        "preferred_game": user.preferred_game,
        "in_game_uid": user.in_game_uid,
        "role": user.role,
        "is_active": user.is_active,
        "created_at": user.created_at,
        "updated_at": user.updated_at,
    }


@router.patch("/users/{user_id}")
async def update_user(
    user_id: str,
    payload: AdminUserUpdate,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Update editable profile fields for a user.

    PATCH /api/admin/users/{user_id}

    Editable:
    - name
    - username
    - bio
    - country
    - state
    - city
    - photo_url
    - social_links
    - preferred_game
    - in_game_uid

    Not editable:
    - email
    - role
    - is_active

    Account suspension remains handled by:
    - PATCH /api/admin/users/{user_id}/suspend
    - PATCH /api/admin/users/{user_id}/unsuspend
    """

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    update_data = payload.model_dump(
        exclude_unset=True
    )

    if not update_data:
        raise HTTPException(
            status_code=400,
            detail="No editable fields were provided",
        )

    # ------------------------------------------------------------
    # Validate username before attempting the database update.
    # ------------------------------------------------------------

    if "username" in update_data:
        new_username = update_data["username"]

        if new_username is not None:
            new_username = new_username.strip()

            if not new_username:
                raise HTTPException(
                    status_code=400,
                    detail="Username cannot be empty",
                )

            if len(new_username) > 20:
                raise HTTPException(
                    status_code=400,
                    detail="Username must not exceed 20 characters",
                )

            existing_user = (
                db.query(User)
                .filter(
                    User.username == new_username,
                    User.id != user_id,
                )
                .first()
            )

            if existing_user:
                raise HTTPException(
                    status_code=409,
                    detail="Username is already taken",
                )

            update_data["username"] = new_username

    # ------------------------------------------------------------
    # Apply profile changes only.
    # ------------------------------------------------------------

    editable_fields = {
        "name",
        "username",
        "bio",
        "country",
        "state",
        "city",
        "photo_url",
        "social_links",
        "preferred_game",
        "in_game_uid",
    }

    for field, value in update_data.items():
        if field not in editable_fields:
            continue

        setattr(user, field, value)

    user.updated_at = datetime.utcnow()

    try:
        db.commit()
        db.refresh(user)

    except IntegrityError:
        db.rollback()

        logger.exception(
            "Integrity error while updating user %s by admin %s",
            user_id,
            admin_id,
        )

        raise HTTPException(
            status_code=409,
            detail="User update conflicts with existing data",
        )

    logger.info(
        "User %s updated by admin %s",
        user_id,
        admin_id,
    )

    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "username": user.username,
        "bio": user.bio,
        "country": user.country,
        "state": user.state,
        "city": user.city,
        "photo_url": user.photo_url,
        "social_links": user.social_links,
        "preferred_game": user.preferred_game,
        "in_game_uid": user.in_game_uid,
        "role": user.role,
        "is_active": user.is_active,
        "created_at": user.created_at,
        "updated_at": user.updated_at,
    }


@router.patch("/users/{user_id}/suspend")
async def suspend_user(
    user_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Suspend user account.

    PATCH /api/admin/users/{user_id}/suspend
    """

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    user.is_active = False

    db.commit()
    db.refresh(user)

    logger.info(
        "User %s suspended by admin %s",
        user_id,
        admin_id,
    )

    return {
        "message": "User suspended",
        "user_id": user_id,
        "is_active": False,
    }


@router.patch("/users/{user_id}/unsuspend")
async def unsuspend_user(
    user_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Unsuspend user account.

    PATCH /api/admin/users/{user_id}/unsuspend
    """

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    user.is_active = True

    db.commit()
    db.refresh(user)

    logger.info(
        "User %s unsuspended by admin %s",
        user_id,
        admin_id,
    )

    return {
        "message": "User unsuspended",
        "user_id": user_id,
        "is_active": True,
    }


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
    db: Session = Depends(get_db),
):
    """
    List all registrations.

    GET /api/admin/registrations
    """

    query = db.query(Registration)

    if status:
        query = query.filter(
            Registration.status == status
        )

    if tournament_id:
        query = query.filter(
            Registration.tournament_id == tournament_id
        )

    total = query.count()

    registrations = (
        query
        .offset(skip)
        .limit(limit)
        .all()
    )

    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "registrations": [
            {
                "id": registration.id,
                "tournament_id": registration.tournament_id,
                "team_id": registration.team_id,
                "status": registration.status,
                "ads_required": registration.ads_required,
                "ads_completed": registration.ads_completed,
                "slot": registration.slot_number,
                "created_at": registration.created_at,
            }
            for registration in registrations
        ],
    }


@router.patch("/registrations/{registration_id}/approve")
async def approve_registration(
    registration_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Approve registration.

    PATCH /api/admin/registrations/{registration_id}/approve
    """

    registration = (
        db.query(Registration)
        .filter(
            Registration.id == registration_id
        )
        .first()
    )

    if not registration:
        raise HTTPException(
            status_code=404,
            detail="Registration not found",
        )

    registration.status = (
        RegistrationStatusEnum.registered
    )

    if not registration.slot_number:
        tournament = (
            db.query(Tournament)
            .filter(
                Tournament.id
                == registration.tournament_id
            )
            .first()
        )

        if tournament:
            max_slot = (
                db.query(func.max(Registration.slot))
                .filter(
                    Registration.tournament_id
                    == tournament.id,
                    Registration.slot.isnot(None),
                )
                .scalar()
                or 0
            )

            registration.slot_number = max_slot + 1

            tournament.registered_teams = (
                tournament.registered_teams or 0
            ) + 1

    db.commit()

    logger.info(
        "Registration %s approved by admin %s",
        registration_id,
        admin_id,
    )

    return {
        "message": "Registration approved",
        "registration_id": registration_id,
    }


@router.patch("/registrations/{registration_id}/reject")
async def reject_registration(
    registration_id: str,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Reject registration.

    PATCH /api/admin/registrations/{registration_id}/reject
    """

    registration = (
        db.query(Registration)
        .filter(
            Registration.id == registration_id
        )
        .first()
    )

    if not registration:
        raise HTTPException(
            status_code=404,
            detail="Registration not found",
        )

    registration.status = (
        RegistrationStatusEnum.rejected
    )

    db.commit()

    logger.info(
        "Registration %s rejected by admin %s",
        registration_id,
        admin_id,
    )

    return {
        "message": "Registration rejected",
        "registration_id": registration_id,
    }


@router.get("/registrations/export")
async def export_registrations(
    tournament_id: Optional[str] = None,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Export registrations as CSV.

    GET /api/admin/registrations/export
    """

    query = (
        db.query(Registration)
        .join(Tournament)
        .join(Team)
        .join(User)
    )

    if tournament_id:
        query = query.filter(
            Registration.tournament_id == tournament_id
        )

    registrations = query.all()

    output = io.StringIO()
    writer = csv.writer(output)

    writer.writerow(
        [
            "Registration ID",
            "Tournament",
            "Team",
            "Captain",
            "Status",
            "Ads Required",
            "Ads Completed",
            "Slot",
            "Created At",
        ]
    )

    for registration in registrations:
        tournament = (
            db.query(Tournament)
            .filter(
                Tournament.id
                == registration.tournament_id
            )
            .first()
        )

        team = (
            db.query(Team)
            .filter(
                Team.id == registration.team_id
            )
            .first()
        )

        captain = None

        if team:
            captain = (
                db.query(User)
                .filter(
                    User.id == team.captain_id
                )
                .first()
            )

        writer.writerow(
            [
                registration.id,
                tournament.name
                if tournament
                else "",
                team.name if team else "",
                captain.name
                if captain
                else "",
                registration.status,
                registration.ads_required,
                registration.ads_completed,
                registration.slot_number or "",
                registration.created_at,
            ]
        )

    csv_content = output.getvalue()

    logger.info(
        "Exported %s registrations",
        len(registrations),
    )

    return {
        "content_type": "text/csv",
        "filename": (
            f"registrations_"
            f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        ),
        "content": csv_content,
    }


# ============================================================================
# TOURNAMENT MANAGEMENT
# ============================================================================

@router.patch(
    "/tournaments/{tournament_id}/status/{new_status}"
)
async def change_tournament_status(
    tournament_id: str,
    new_status: TournamentStatusEnum,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Change tournament status.

    PATCH /api/admin/tournaments/{tournament_id}/status/{new_status}
    """

    tournament = (
        db.query(Tournament)
        .filter(
            Tournament.id == tournament_id
        )
        .first()
    )

    if not tournament:
        raise HTTPException(
            status_code=404,
            detail="Tournament not found",
        )

    tournament.status = new_status

    db.commit()

    logger.info(
        "Tournament %s status changed to %s by admin %s",
        tournament_id,
        new_status,
        admin_id,
    )

    return {
        "message": "Tournament status updated",
        "tournament_id": tournament_id,
        "status": new_status,
    }


@router.patch(
    "/tournaments/{tournament_id}/config"
)
async def update_tournament_config(
    tournament_id: str,
    payload: dict,
    admin_id: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Update tournament configuration.

    PATCH /api/admin/tournaments/{tournament_id}/config

    Example body:
    {
        "ads_required": 3,
        "policy": "captain_ads"
    }
    """

    tournament = (
        db.query(Tournament)
        .filter(
            Tournament.id == tournament_id
        )
        .first()
    )

    if not tournament:
        raise HTTPException(
            status_code=404,
            detail="Tournament not found",
        )

    if "ads_required" in payload:
        tournament.ads_required = payload["ads_required"]

    if "policy" in payload:
        tournament.policy = payload["policy"]

    db.commit()

    logger.info(
        "Tournament %s config updated by admin %s",
        tournament_id,
        admin_id,
    )

    return {
        "message": "Tournament configuration updated",
        "tournament_id": tournament_id,
    }


# ============================================================================
# TEAM MANAGEMENT
# ============================================================================

@router.get("/teams")
async def list_teams(
    skip: int = 0,
    limit: int = 10,
    game: Optional[str] = None,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    List all teams.

    GET /api/admin/teams
    """

    query = db.query(Team)

    if game:
        query = query.filter(
            Team.game == game
        )

    total = query.count()

    teams = (
        query
        .offset(skip)
        .limit(limit)
        .all()
    )

    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "teams": [
            {
                "id": team.id,
                "name": team.name,
                "game": team.game,
                "captain_id": team.captain_id,
                "is_private": team.is_private,
                "member_count": (
                    len(team.members)
                    if team.members
                    else 0
                ),
                "created_at": team.created_at,
            }
            for team in teams
        ],
    }


@router.get("/teams/{team_id}")
async def get_team_details(
    team_id: str,
    _: str = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Get team details with members and registrations.

    GET /api/admin/teams/{team_id}
    """

    team = (
        db.query(Team)
        .filter(Team.id == team_id)
        .first()
    )

    if not team:
        raise HTTPException(
            status_code=404,
            detail="Team not found",
        )

    members = (
        db.query(User)
        .join(TeamMember)
        .filter(
            TeamMember.team_id == team_id
        )
        .all()
    )

    registrations = (
        db.query(Registration)
        .filter(
            Registration.team_id == team_id
        )
        .all()
    )

    return {
        "id": team.id,
        "name": team.name,
        "game": team.game,
        "captain_id": team.captain_id,
        "is_private": team.is_private,
        "logo_url": team.logo_url,
        "created_at": team.created_at,
        "members": [
            {
                "id": member.id,
                "name": member.name,
                "username": member.username,
                "email": member.email,
            }
            for member in members
        ],
        "registrations": [
            {
                "id": registration.id,
                "tournament_id": registration.tournament_id,
                "status": registration.status,
                "ads_completed": registration.ads_completed,
            }
            for registration in registrations
        ],
    }