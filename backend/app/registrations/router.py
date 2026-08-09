"""Tournament registration and rewarded-ad completion endpoints."""

import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.common.deps import current_user_id
from app.common.models import (
    AdCompletion,
    Registration as RegistrationSchema,
    RegistrationStatus,
)
from app.core.database import get_db
from app.core.models import (
    Registration,
    RegistrationPolicyEnum,
    RegistrationStatusEnum,
    Team,
    Tournament,
    TournamentStatusEnum,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def to_schema(registration: Registration) -> RegistrationSchema:
    """Convert SQLAlchemy Registration model to Pydantic schema."""

    try:
        completed_by = json.loads(registration.completed_by or "[]")
    except (json.JSONDecodeError, TypeError):
        completed_by = []

    return RegistrationSchema(
        id=registration.id,
        tournament_id=registration.tournament_id,
        team_id=registration.team_id,
        captain_id=registration.user_id,
        status=RegistrationStatus(registration.status.value),
        ads_required=registration.ads_required,
        ads_completed=registration.ads_completed,
        completed_by=completed_by,
        slot=(
            registration.slot_number
            if registration.slot_assigned
            else None
        ),
    )


def get_team_members(db: Session, team_id: str) -> list[str]:
    """Return all user IDs belonging to a team."""

    team = (
        db.query(Team)
        .filter(Team.id == team_id)
        .first()
    )

    if not team:
        return []

    return [member.user_id for member in team.members]


def get_required_ads(
    tournament: Tournament,
    policy: RegistrationPolicyEnum,
    team_members: list[str],
) -> int:
    """
    Calculate the number of required ads.

    INDIVIDUAL_ADS:
        Every team member must complete one ad.

    CAPTAIN_ADS:
        Only the captain completes the tournament's configured
        number of required ads.
    """

    if policy == RegistrationPolicyEnum.individual_ads:
        return len(team_members)

    return tournament.ads_required


# ============================================================
# START REGISTRATION
# ============================================================

@router.post(
    "/tournaments/{tournament_id}/teams/{team_id}",
    response_model=RegistrationSchema,
    tags=["registrations"],
)
async def start_registration(
    tournament_id: str,
    team_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Start tournament registration for a team.

    Flow:
        1. Validate tournament
        2. Validate team
        3. Verify captain
        4. Verify tournament is published
        5. Check available slots
        6. Check duplicate registration
        7. Calculate required ads
        8. Create registration with PENDING status
    """

    # --------------------------------------------------------
    # 1. Get tournament
    # --------------------------------------------------------

    tournament = (
        db.query(Tournament)
        .filter(Tournament.id == tournament_id)
        .first()
    )

    if not tournament:
        logger.warning(
            "Tournament %s not found",
            tournament_id,
        )
        raise HTTPException(
            status_code=404,
            detail="Tournament not found",
        )

    # --------------------------------------------------------
    # 2. Get team
    # --------------------------------------------------------

    team = (
        db.query(Team)
        .filter(Team.id == team_id)
        .first()
    )

    if not team:
        logger.warning(
            "Team %s not found",
            team_id,
        )
        raise HTTPException(
            status_code=404,
            detail="Team not found",
        )

    # --------------------------------------------------------
    # 3. Verify captain
    # --------------------------------------------------------

    if team.captain_id != user_id:
        logger.warning(
            "User %s is not captain of team %s",
            user_id,
            team_id,
        )
        raise HTTPException(
            status_code=403,
            detail="Only the team captain can register",
        )

    # --------------------------------------------------------
    # 4. Check tournament status
    # --------------------------------------------------------

    if tournament.status != TournamentStatusEnum.published:
        logger.warning(
            "Tournament %s is not published. Current status: %s",
            tournament_id,
            tournament.status,
        )
        raise HTTPException(
            status_code=409,
            detail=(
                f"Tournament is {tournament.status}, "
                "not open for registration"
            ),
        )

    # --------------------------------------------------------
    # 5. Check available slots
    # --------------------------------------------------------

    if tournament.registered_teams >= tournament.total_slots:
        logger.warning(
            "Tournament %s is full",
            tournament_id,
        )
        raise HTTPException(
            status_code=409,
            detail="Tournament is full, no slots available",
        )

    # --------------------------------------------------------
    # 6. Check existing registration
    # --------------------------------------------------------

    existing = (
        db.query(Registration)
        .filter(
            Registration.tournament_id == tournament_id,
            Registration.team_id == team_id,
        )
        .first()
    )

    if existing:
        logger.info(
            "Team %s already registered for tournament %s",
            team_id,
            tournament_id,
        )
        return to_schema(existing)

    # --------------------------------------------------------
    # 7. Calculate required ads
    # --------------------------------------------------------

    team_members = get_team_members(
        db,
        team_id,
    )

    required_ads = get_required_ads(
        tournament,
        tournament.policy,
        team_members,
    )

    # --------------------------------------------------------
    # 8. Create registration
    # --------------------------------------------------------

    registration = Registration(
        tournament_id=tournament_id,
        team_id=team_id,
        user_id=user_id,
        ads_required=required_ads,
        ads_completed=0,
        status=RegistrationStatusEnum.pending,
        completed_by="[]",
        slot_assigned=False,
        slot_number=None,
    )

    db.add(registration)
    db.commit()
    db.refresh(registration)

    logger.info(
        "Registration started: %s | Tournament: %s | Team: %s",
        registration.id,
        tournament_id,
        team_id,
    )

    return to_schema(registration)


# ============================================================
# START AD VERIFICATION
# ============================================================

@router.post(
    "/{registration_id}/ads/start",
    response_model=RegistrationSchema,
    tags=["registrations"],
)
async def start_ad_verification(
    registration_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Start the rewarded-ad verification process.

    PENDING -> AD_VERIFICATION

    Only the registration captain can start the process.
    """

    registration = (
        db.query(Registration)
        .filter(Registration.id == registration_id)
        .first()
    )

    if not registration:
        raise HTTPException(
            status_code=404,
            detail="Registration not found",
        )

    # Only captain can start verification
    if registration.user_id != user_id:
        raise HTTPException(
            status_code=403,
            detail=(
                "Only registration captain can "
                "start ad verification"
            ),
        )

    # Must currently be pending
    if registration.status != RegistrationStatusEnum.pending:
        raise HTTPException(
            status_code=400,
            detail=(
                "Can only start from pending status "
                f"(current: {registration.status})"
            ),
        )

    registration.status = RegistrationStatusEnum.ad_verification
    registration.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(registration)

    logger.info(
        "Ad verification started for registration %s",
        registration_id,
    )

    return to_schema(registration)


# ============================================================
# COMPLETE AD
# ============================================================

@router.post(
    "/{registration_id}/ads/complete",
    response_model=RegistrationSchema,
    tags=["registrations"],
)
async def complete_ad(
    registration_id: str,
    payload: AdCompletion,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Record completion of a rewarded advertisement.

    INDIVIDUAL_ADS:
        Each team member completes one ad.

    CAPTAIN_ADS:
        Only the captain completes ads.

    Duplicate completions by the same user are ignored.
    """

    # --------------------------------------------------------
    # 1. Get registration
    # --------------------------------------------------------

    registration = (
        db.query(Registration)
        .filter(Registration.id == registration_id)
        .first()
    )

    if not registration:
        raise HTTPException(
            status_code=404,
            detail="Registration not found",
        )

    # --------------------------------------------------------
    # 2. Verify registration ID
    # --------------------------------------------------------

    if registration.id != payload.registration_id:
        raise HTTPException(
            status_code=400,
            detail="Registration ID mismatch",
        )

    # --------------------------------------------------------
    # 3. Verify authenticated viewer
    # --------------------------------------------------------

    if payload.viewer_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="You can only complete ads for yourself",
        )

    # --------------------------------------------------------
    # 4. Verify ad
    # --------------------------------------------------------

    # Temporary/mock verification.
    # Replace this with real rewarded-ad verification later.
    if payload.verification_token == "invalid":
        raise HTTPException(
            status_code=422,
            detail="Ad verification failed",
        )

    # --------------------------------------------------------
    # 5. Get tournament and team
    # --------------------------------------------------------

    tournament = (
        db.query(Tournament)
        .filter(
            Tournament.id == registration.tournament_id
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

    if not tournament or not team:
        raise HTTPException(
            status_code=404,
            detail="Tournament or team not found",
        )

    # --------------------------------------------------------
    # 6. Load completion list
    # --------------------------------------------------------

    try:
        completed_by = json.loads(
            registration.completed_by or "[]"
        )
    except (json.JSONDecodeError, TypeError):
        completed_by = []

    # --------------------------------------------------------
    # 7. Validate policy
    # --------------------------------------------------------

    if tournament.policy == RegistrationPolicyEnum.individual_ads:

        team_member_ids = get_team_members(
            db,
            registration.team_id,
        )

        if user_id not in team_member_ids:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Only team members can complete ads "
                    "for individual ads policy"
                ),
            )

    else:
        # Captain Ads
        if user_id != registration.user_id:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Only team captain can complete ads "
                    "for captain ads policy"
                ),
            )

    # --------------------------------------------------------
    # 8. Prevent duplicate completion
    # --------------------------------------------------------

    if user_id not in completed_by:

        completed_by.append(user_id)

        registration.completed_by = json.dumps(
            completed_by
        )

        registration.ads_completed += 1

        logger.info(
            "Ad completed | User: %s | Registration: %s | "
            "Completed: %s/%s",
            user_id,
            registration_id,
            registration.ads_completed,
            registration.ads_required,
        )

    else:

        logger.info(
            "Duplicate ad completion ignored | User: %s | "
            "Registration: %s",
            user_id,
            registration_id,
        )

    # --------------------------------------------------------
    # 9. Check whether registration is complete
    # --------------------------------------------------------

    required_ads = registration.ads_required

    if (
        registration.ads_completed >= required_ads
        and registration.status != RegistrationStatusEnum.registered
    ):

        # Assign next available slot
        registration.status = RegistrationStatusEnum.registered

        registration.slot_assigned = True

        registration.slot_number = (
            tournament.registered_teams + 1
        )

        tournament.registered_teams += 1

        logger.info(
            "Registration completed | Registration: %s | "
            "Slot: %s",
            registration_id,
            registration.slot_number,
        )

    registration.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(registration)

    return to_schema(registration)


# ============================================================
# CANCEL REGISTRATION
# ============================================================

@router.post(
    "/{registration_id}/cancel",
    tags=["registrations"],
)
async def cancel_registration(
    registration_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Cancel an incomplete registration.

    Only the captain can cancel.
    Completed registrations cannot be cancelled.
    """

    registration = (
        db.query(Registration)
        .filter(Registration.id == registration_id)
        .first()
    )

    if not registration:
        raise HTTPException(
            status_code=404,
            detail="Registration not found",
        )

    if registration.user_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="Only captain can cancel",
        )

    if registration.status == RegistrationStatusEnum.registered:
        raise HTTPException(
            status_code=400,
            detail="Cannot cancel completed registration",
        )

    db.delete(registration)
    db.commit()

    logger.info(
        "Registration %s cancelled by %s",
        registration_id,
        user_id,
    )

    return {
        "success": True,
        "message": "Registration cancelled",
        "registration_id": registration_id,
    }


# ============================================================
# GET REGISTRATION DETAILS
# ============================================================

@router.get(
    "/{registration_id}",
    response_model=RegistrationSchema,
    tags=["registrations"],
)
async def get_registration_details(
    registration_id: str,
    db: Session = Depends(get_db),
):
    """Get a single registration."""

    registration = (
        db.query(Registration)
        .filter(Registration.id == registration_id)
        .first()
    )

    if not registration:
        raise HTTPException(
            status_code=404,
            detail="Registration not found",
        )

    return to_schema(registration)


# ============================================================
# GET TOURNAMENT REGISTRATIONS
# ============================================================

@router.get(
    "/tournament/{tournament_id}",
    response_model=list[RegistrationSchema],
    tags=["registrations"],
)
async def get_tournament_registrations(
    tournament_id: str,
    db: Session = Depends(get_db),
):
    """Get all registrations for a tournament."""

    registrations = (
        db.query(Registration)
        .filter(
            Registration.tournament_id == tournament_id
        )
        .all()
    )

    return [
        to_schema(registration)
        for registration in registrations
    ]


# ============================================================
# GET TEAM REGISTRATIONS
# ============================================================

@router.get(
    "/team/{team_id}",
    response_model=list[RegistrationSchema],
    tags=["registrations"],
)
async def get_team_registrations(
    team_id: str,
    db: Session = Depends(get_db),
):
    """Get all registrations for a team."""

    registrations = (
        db.query(Registration)
        .filter(
            Registration.team_id == team_id
        )
        .all()
    )

    return [
        to_schema(registration)
        for registration in registrations
    ]


# ============================================================
# GET CURRENT USER REGISTRATIONS
# ============================================================

@router.get(
    "/user/me",
    response_model=list[RegistrationSchema],
    tags=["registrations"],
)
async def my_registrations(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """Get current user's registrations as captain."""

    registrations = (
        db.query(Registration)
        .filter(
            Registration.user_id == user_id
        )
        .all()
    )

    return [
        to_schema(registration)
        for registration in registrations
    ]


# ============================================================
# CHECK REGISTRATION STATUS
# ============================================================

@router.get(
    "/status/{registration_id}",
    tags=["registrations"],
)
async def check_registration_status(
    registration_id: str,
    db: Session = Depends(get_db),
):
    """Check registration progress and completion status."""

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

    try:
        completed_by = json.loads(
            registration.completed_by or "[]"
        )
    except (json.JSONDecodeError, TypeError):
        completed_by = []

    return {
        "registration_id": registration_id,
        "status": registration.status.value,
        "ads_required": registration.ads_required,
        "ads_completed": registration.ads_completed,
        "members_completed": completed_by,
        "is_complete": (
            registration.status
            == RegistrationStatusEnum.registered
        ),
        "slot": (
            registration.slot_number
            if registration.slot_assigned
            else None
        ),
    }
