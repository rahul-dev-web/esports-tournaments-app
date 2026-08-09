"""
Team management endpoints
- Create, read, update, delete teams
- Team member management
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.models import Team, TeamMember, User, TeamInvitation, TournamentStatusEnum, InvitationStatusEnum
from app.common.models import (Team as TeamSchema, TeamCreate, TeamInvitationCreate, TeamInvitationResponse, InvitationActionRequest, TeamInvitationList)
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
    game: Optional[str] = None,
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

# ============================================================
# TEAM INVITATION ENDPOINTS
# ============================================================


# ============================================================
# SEND INVITATION
# ============================================================

@router.post(
    "/{team_id}/invitations",
    response_model=TeamInvitationResponse,
    tags=["teams"],
)
async def send_team_invitation(
    team_id: str,
    payload: TeamInvitationCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Send invitation to join team.

    Only team captain can send invitations.
    """

    # 1. Check team
    team = db.query(Team).filter(Team.id == team_id).first()

    if not team:
        raise HTTPException(
            status_code=404,
            detail="Team not found",
        )

    # 2. Check captain
    if team.captain_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="Only team captain can send invitations",
        )

    # 3. Check receiver
    receiver = (
        db.query(User)
        .filter(User.id == payload.receiver_id)
        .first()
    )

    if not receiver:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    # 4. Cannot invite yourself
    if payload.receiver_id == user_id:
        raise HTTPException(
            status_code=400,
            detail="You cannot invite yourself",
        )

    # 5. Check existing team membership
    existing_member = (
        db.query(TeamMember)
        .filter(
            TeamMember.team_id == team_id,
            TeamMember.user_id == payload.receiver_id,
        )
        .first()
    )

    if existing_member:
        raise HTTPException(
            status_code=400,
            detail="User is already a member of this team",
        )

    # 6. Check existing pending invitation
    existing_invite = (
        db.query(TeamInvitation)
        .filter(
            TeamInvitation.team_id == team_id,
            TeamInvitation.receiver_id == payload.receiver_id,
            TeamInvitation.status == InvitationStatusEnum.pending,
        )
        .first()
    )

    if existing_invite:
        raise HTTPException(
            status_code=400,
            detail="Invitation already sent to this user",
        )

    # 7. Invitation expires after 7 days
    expires_at = datetime.utcnow() + timedelta(days=7)

    invitation = TeamInvitation(
        team_id=team_id,
        sender_id=user_id,
        receiver_id=payload.receiver_id,
        message=payload.message,
        expires_at=expires_at,
        status=InvitationStatusEnum.pending,
    )

    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    logger.info(
        f"Invitation sent: {invitation.id} "
        f"(Team: {team_id}, To: {payload.receiver_id})"
    )

    return TeamInvitationResponse.model_validate(invitation)


# ============================================================
# GET RECEIVED INVITATIONS
# ============================================================

@router.get(
    "/invitations/received",
    response_model=list[TeamInvitationList],
    tags=["teams"],
)
async def get_received_invitations(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Get pending invitations received by current user.
    """

    invitations = (
        db.query(TeamInvitation)
        .filter(
            TeamInvitation.receiver_id == user_id,
            TeamInvitation.status == InvitationStatusEnum.pending,
            TeamInvitation.expires_at > datetime.utcnow(),
        )
        .all()
    )

    result = []

    for inv in invitations:
        result.append(
            {
                "id": inv.id,
                "team": {
                    "id": inv.team.id,
                    "name": inv.team.name,
                    "game": inv.team.game,
                    "captain_id": inv.team.captain_id,
                },
                "sender": {
                    "id": inv.sender.id,
                    "name": inv.sender.name,
                    "username": inv.sender.username,
                },
                "status": inv.status,
                "message": inv.message,
                "created_at": inv.created_at,
                "expires_at": inv.expires_at,
            }
        )

    return result


# ============================================================
# GET TEAM INVITATIONS
# ============================================================

@router.get(
    "/{team_id}/invitations",
    response_model=list[TeamInvitationResponse],
    tags=["teams"],
)
async def get_team_invitations(
    team_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Get all invitations sent for a team.

    Only team captain can view them.
    """

    team = db.query(Team).filter(Team.id == team_id).first()

    if not team:
        raise HTTPException(
            status_code=404,
            detail="Team not found",
        )

    if team.captain_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="Only captain can view team invitations",
        )

    invitations = (
        db.query(TeamInvitation)
        .filter(TeamInvitation.team_id == team_id)
        .order_by(TeamInvitation.created_at.desc())
        .all()
    )

    return [
        TeamInvitationResponse.model_validate(inv)
        for inv in invitations
    ]


# ============================================================
# ACCEPT INVITATION
# ============================================================

@router.post(
    "/invitations/{invitation_id}/accept",
    tags=["teams"],
)
async def accept_invitation(
    invitation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Accept a team invitation.
    """

    invitation = (
        db.query(TeamInvitation)
        .filter(TeamInvitation.id == invitation_id)
        .first()
    )

    if not invitation:
        raise HTTPException(
            status_code=404,
            detail="Invitation not found",
        )

    # Make sure invitation belongs to current user
    if invitation.receiver_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="This invitation is not for you",
        )

    # Must be pending
    if invitation.status != InvitationStatusEnum.pending:
        raise HTTPException(
            status_code=400,
            detail=f"Invitation already {invitation.status.value}",
        )

    # Check expiration
    if invitation.expires_at < datetime.utcnow():
        invitation.status = InvitationStatusEnum.expired
        db.commit()

        raise HTTPException(
            status_code=400,
            detail="Invitation expired",
        )

    # Prevent duplicate membership
    existing_member = (
        db.query(TeamMember)
        .filter(
            TeamMember.team_id == invitation.team_id,
            TeamMember.user_id == user_id,
        )
        .first()
    )

    if existing_member:
        invitation.status = InvitationStatusEnum.accepted
        db.commit()

        raise HTTPException(
            status_code=400,
            detail="You are already a member of this team",
        )

    # Add user to team
    team_member = TeamMember(
        team_id=invitation.team_id,
        user_id=user_id,
    )

    db.add(team_member)

    # Update invitation
    invitation.status = InvitationStatusEnum.accepted
    invitation.updated_at = datetime.utcnow()

    db.commit()

    logger.info(
        f"Invitation {invitation_id} accepted by {user_id}"
    )

    return {
        "success": True,
        "message": f"Successfully joined team {invitation.team.name}",
        "team_id": invitation.team_id,
    }


# ============================================================
# REJECT INVITATION
# ============================================================

@router.post(
    "/invitations/{invitation_id}/reject",
    tags=["teams"],
)
async def reject_invitation(
    invitation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Reject a team invitation.
    """

    invitation = (
        db.query(TeamInvitation)
        .filter(TeamInvitation.id == invitation_id)
        .first()
    )

    if not invitation:
        raise HTTPException(
            status_code=404,
            detail="Invitation not found",
        )

    if invitation.receiver_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="This invitation is not for you",
        )

    if invitation.status != InvitationStatusEnum.pending:
        raise HTTPException(
            status_code=400,
            detail=f"Invitation already {invitation.status.value}",
        )

    invitation.status = InvitationStatusEnum.rejected
    invitation.updated_at = datetime.utcnow()

    db.commit()

    logger.info(
        f"Invitation {invitation_id} rejected by {user_id}"
    )

    return {
        "success": True,
        "message": "Invitation rejected",
    }


# ============================================================
# CANCEL INVITATION
# ============================================================

@router.post(
    "/invitations/{invitation_id}/cancel",
    tags=["teams"],
)
async def cancel_invitation(
    invitation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """
    Cancel a pending invitation.

    Only the invitation sender/captain can cancel it.
    """

    invitation = (
        db.query(TeamInvitation)
        .filter(TeamInvitation.id == invitation_id)
        .first()
    )

    if not invitation:
        raise HTTPException(
            status_code=404,
            detail="Invitation not found",
        )

    if invitation.sender_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="Only invitation sender can cancel",
        )

    if invitation.status != InvitationStatusEnum.pending:
        raise HTTPException(
            status_code=400,
            detail=(
                "Can only cancel pending invitations "
                f"(current: {invitation.status.value})"
            ),
        )

    invitation.status = InvitationStatusEnum.cancelled
    invitation.updated_at = datetime.utcnow()

    db.commit()

    logger.info(
        f"Invitation {invitation_id} cancelled by {user_id}"
    )

    return {
        "success": True,
        "message": "Invitation cancelled",
    }


# ============================================================
# GET INVITATION DETAILS
# ============================================================

@router.get(
    "/invitations/{invitation_id}",
    response_model=TeamInvitationResponse,
    tags=["teams"],
)
async def get_invitation_details(
    invitation_id: str,
    db: Session = Depends(get_db),
):
    """
    Get details of a specific invitation.
    """

    invitation = (
        db.query(TeamInvitation)
        .filter(TeamInvitation.id == invitation_id)
        .first()
    )

    if not invitation:
        raise HTTPException(
            status_code=404,
            detail="Invitation not found",
        )

    return TeamInvitationResponse.model_validate(invitation)
