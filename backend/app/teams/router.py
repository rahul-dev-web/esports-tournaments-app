"""Team management endpoints.

The team router owns team CRUD, membership and invitation workflows.  Team
lifecycle events also create user notifications and best-effort FCM pushes.
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.common.deps import current_user_id
from app.common.models import (
    Team as TeamSchema,
    TeamCreate,
    TeamInvitationCreate,
    TeamInvitationList,
    TeamInvitationResponse,
)
from app.core.database import get_db
from app.core.models import (
    InvitationStatusEnum,
    Team,
    TeamInvitation,
    TeamMember,
    User,
)
from app.notifications.service import notify_user

import logging

logger = logging.getLogger(__name__)
router = APIRouter()


def _team_display_name(team: Team) -> str:
    return team.name or "your team"


@router.post("", response_model=TeamSchema, tags=["teams"])
async def create_team(
    payload: TeamCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    existing = db.query(Team).filter(Team.name == payload.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Team name already exists")

    team = Team(
        name=payload.name,
        game=payload.game,
        captain_id=user_id,
        is_private=payload.is_private,
        logo_url=payload.logo_url,
    )
    db.add(team)
    db.flush()
    db.add(TeamMember(team_id=team.id, user_id=user_id))
    db.commit()
    db.refresh(team)

    logger.info("Team %s created by %s", team.id, user_id)
    return TeamSchema.from_orm(team)


@router.get("", response_model=list[TeamSchema], tags=["teams"])
async def list_teams(
    game: Optional[str] = None,
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db),
):
    query = db.query(Team)
    if game:
        query = query.filter(Team.game == game)
    return [TeamSchema.from_orm(t) for t in query.offset(skip).limit(limit).all()]


# Keep static paths before /{team_id}; otherwise FastAPI can interpret
# "invitations" as a team_id and make the invitation endpoint unreachable.
@router.get(
    "/user/my-teams",
    response_model=list[TeamSchema],
    tags=["teams"],
)
async def get_my_teams(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    teams = (
        db.query(Team)
        .join(TeamMember)
        .filter(TeamMember.user_id == user_id)
        .all()
    )
    return [TeamSchema.from_orm(team) for team in teams]


@router.get(
    "/invitations/received",
    response_model=list[TeamInvitationList],
    tags=["teams"],
)
async def get_received_invitations(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    invitations = (
        db.query(TeamInvitation)
        .filter(
            TeamInvitation.receiver_id == user_id,
            TeamInvitation.status == InvitationStatusEnum.pending,
            TeamInvitation.expires_at > datetime.utcnow(),
        )
        .order_by(TeamInvitation.created_at.desc())
        .all()
    )

    return [
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
        for inv in invitations
    ]


@router.get(
    "/{team_id}",
    response_model=TeamSchema,
    tags=["teams"],
)
async def get_team(team_id: str, db: Session = Depends(get_db)):
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    return TeamSchema.from_orm(team)


@router.get("/{team_id}/members", tags=["teams"])
async def get_team_members(team_id: str, db: Session = Depends(get_db)):
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    members = (
        db.query(User, TeamMember)
        .join(TeamMember, TeamMember.user_id == User.id)
        .filter(TeamMember.team_id == team_id)
        .all()
    )
    return [
        {
            "id": user.id,
            "name": user.name,
            "username": user.username,
            "photo_url": user.photo_url,
            "is_captain": user.id == team.captain_id,
            "joined_at": team_member.joined_at,
        }
        for user, team_member in members
    ]


@router.patch("/{team_id}", response_model=TeamSchema, tags=["teams"])
async def update_team(
    team_id: str,
    payload: TeamCreate,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can update team")

    if payload.name != team.name:
        duplicate = db.query(Team).filter(Team.name == payload.name, Team.id != team_id).first()
        if duplicate:
            raise HTTPException(status_code=400, detail="Team name already exists")

    team.name = payload.name
    team.game = payload.game
    team.is_private = payload.is_private
    team.logo_url = payload.logo_url
    db.commit()
    db.refresh(team)
    return TeamSchema.from_orm(team)


@router.delete("/{team_id}", tags=["teams"])
async def delete_team(
    team_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can delete team")

    member_ids = [m.user_id for m in team.members if m.user_id != user_id]
    team_name = _team_display_name(team)
    db.delete(team)
    db.commit()

    for member_id in member_ids:
        notify_user(
            db,
            user_id=member_id,
            title="Team deleted",
            body=f'Team "{team_name}" was deleted by the captain.',
            notification_type="team_deleted",
            data={"team_id": team_id},
        )
    return {"success": True, "message": "Team deleted"}


@router.post("/{team_id}/members/{new_user_id}", tags=["teams"])
async def add_member(
    team_id: str,
    new_user_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    if new_user_id != user_id:
        raise HTTPException(status_code=403, detail="You can only add yourself through the join flow")

    pending_invite = (
        db.query(TeamInvitation)
        .filter(
            TeamInvitation.team_id == team_id,
            TeamInvitation.receiver_id == user_id,
            TeamInvitation.status == InvitationStatusEnum.pending,
            TeamInvitation.expires_at > datetime.utcnow(),
        )
        .first()
    )
    if team.is_private and not pending_invite:
        raise HTTPException(status_code=403, detail="Private teams require a valid invitation")

    if db.query(TeamMember).filter(TeamMember.team_id == team_id, TeamMember.user_id == user_id).first():
        raise HTTPException(status_code=400, detail="User already in team")

    db.add(TeamMember(team_id=team_id, user_id=user_id))
    if pending_invite:
        pending_invite.status = InvitationStatusEnum.accepted
        pending_invite.updated_at = datetime.utcnow()
    db.commit()

    if pending_invite:
        notify_user(
            db,
            user_id=pending_invite.sender_id,
            title="Team invitation accepted",
            body=f'{pending_invite.receiver.name or "A player"} joined "{_team_display_name(team)}".',
            notification_type="team_invitation_accepted",
            data={"team_id": team_id, "invitation_id": pending_invite.id},
        )
    return {"success": True, "message": "Member added"}


@router.delete("/{team_id}/members/{member_user_id}", tags=["teams"])
async def remove_member(
    team_id: str,
    member_user_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can remove members")
    if member_user_id == user_id:
        raise HTTPException(status_code=400, detail="Captain cannot remove themselves")

    member = db.query(TeamMember).filter(
        TeamMember.team_id == team_id,
        TeamMember.user_id == member_user_id,
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not in team")

    team_name = _team_display_name(team)
    db.delete(member)
    db.commit()
    notify_user(
        db,
        user_id=member_user_id,
        title="Removed from team",
        body=f'You were removed from "{team_name}" by the captain.',
        notification_type="team_member_removed",
        data={"team_id": team_id},
    )
    return {"success": True, "message": "Member removed"}


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
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only team captain can send invitations")

    receiver = db.query(User).filter(User.id == payload.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="User not found")
    if payload.receiver_id == user_id:
        raise HTTPException(status_code=400, detail="You cannot invite yourself")
    if db.query(TeamMember).filter(
        TeamMember.team_id == team_id,
        TeamMember.user_id == payload.receiver_id,
    ).first():
        raise HTTPException(status_code=400, detail="User is already a member of this team")
    if db.query(TeamInvitation).filter(
        TeamInvitation.team_id == team_id,
        TeamInvitation.receiver_id == payload.receiver_id,
        TeamInvitation.status == InvitationStatusEnum.pending,
        TeamInvitation.expires_at > datetime.utcnow(),
    ).first():
        raise HTTPException(status_code=400, detail="Invitation already sent to this user")

    invitation = TeamInvitation(
        team_id=team_id,
        sender_id=user_id,
        receiver_id=payload.receiver_id,
        message=payload.message,
        expires_at=datetime.utcnow() + timedelta(days=7),
        status=InvitationStatusEnum.pending,
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    notify_user(
        db,
        user_id=receiver.id,
        title="New team invitation",
        body=f'{team.captain.name or "The captain"} invited you to join "{_team_display_name(team)}".',
        notification_type="team_invitation",
        data={"team_id": team_id, "invitation_id": invitation.id},
    )
    return TeamInvitationResponse.model_validate(invitation)


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
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    if team.captain_id != user_id:
        raise HTTPException(status_code=403, detail="Only captain can view team invitations")

    invitations = (
        db.query(TeamInvitation)
        .filter(TeamInvitation.team_id == team_id)
        .order_by(TeamInvitation.created_at.desc())
        .all()
    )
    return [TeamInvitationResponse.model_validate(inv) for inv in invitations]


@router.post("/invitations/{invitation_id}/accept", tags=["teams"])
async def accept_invitation(
    invitation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    invitation = db.query(TeamInvitation).filter(TeamInvitation.id == invitation_id).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.receiver_id != user_id:
        raise HTTPException(status_code=403, detail="This invitation is not for you")
    if invitation.status != InvitationStatusEnum.pending:
        raise HTTPException(status_code=400, detail=f"Invitation already {invitation.status.value}")
    if invitation.expires_at < datetime.utcnow():
        invitation.status = InvitationStatusEnum.expired
        invitation.updated_at = datetime.utcnow()
        db.commit()
        raise HTTPException(status_code=400, detail="Invitation expired")
    if db.query(TeamMember).filter(
        TeamMember.team_id == invitation.team_id,
        TeamMember.user_id == user_id,
    ).first():
        invitation.status = InvitationStatusEnum.accepted
        invitation.updated_at = datetime.utcnow()
        db.commit()
        raise HTTPException(status_code=400, detail="You are already a member of this team")

    team = invitation.team
    db.add(TeamMember(team_id=invitation.team_id, user_id=user_id))
    invitation.status = InvitationStatusEnum.accepted
    invitation.updated_at = datetime.utcnow()
    db.commit()

    notify_user(
        db,
        user_id=invitation.sender_id,
        title="Team invitation accepted",
        body=f'{invitation.receiver.name or "A player"} joined "{_team_display_name(team)}".',
        notification_type="team_invitation_accepted",
        data={"team_id": invitation.team_id, "invitation_id": invitation.id},
    )
    return {
        "success": True,
        "message": f"Successfully joined team {team.name}",
        "team_id": invitation.team_id,
    }


@router.post("/invitations/{invitation_id}/reject", tags=["teams"])
async def reject_invitation(
    invitation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    invitation = db.query(TeamInvitation).filter(TeamInvitation.id == invitation_id).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.receiver_id != user_id:
        raise HTTPException(status_code=403, detail="This invitation is not for you")
    if invitation.status != InvitationStatusEnum.pending:
        raise HTTPException(status_code=400, detail=f"Invitation already {invitation.status.value}")

    team_name = _team_display_name(invitation.team)
    invitation.status = InvitationStatusEnum.rejected
    invitation.updated_at = datetime.utcnow()
    db.commit()
    notify_user(
        db,
        user_id=invitation.sender_id,
        title="Team invitation declined",
        body=f'{invitation.receiver.name or "A player"} declined your invitation to "{team_name}".',
        notification_type="team_invitation_rejected",
        data={"team_id": invitation.team_id, "invitation_id": invitation.id},
    )
    return {"success": True, "message": "Invitation rejected"}


@router.post("/invitations/{invitation_id}/cancel", tags=["teams"])
async def cancel_invitation(
    invitation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    invitation = db.query(TeamInvitation).filter(TeamInvitation.id == invitation_id).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.sender_id != user_id:
        raise HTTPException(status_code=403, detail="Only invitation sender can cancel")
    if invitation.status != InvitationStatusEnum.pending:
        raise HTTPException(
            status_code=400,
            detail=f"Can only cancel pending invitations (current: {invitation.status.value})",
        )

    team_name = _team_display_name(invitation.team)
    receiver_id = invitation.receiver_id
    invitation.status = InvitationStatusEnum.cancelled
    invitation.updated_at = datetime.utcnow()
    db.commit()
    notify_user(
        db,
        user_id=receiver_id,
        title="Team invitation cancelled",
        body=f'The invitation to join "{team_name}" was cancelled.',
        notification_type="team_invitation_cancelled",
        data={"team_id": invitation.team_id, "invitation_id": invitation.id},
    )
    return {"success": True, "message": "Invitation cancelled"}


@router.get("/invitations/{invitation_id}", response_model=TeamInvitationResponse, tags=["teams"])
async def get_invitation_details(
    invitation_id: str,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    invitation = db.query(TeamInvitation).filter(TeamInvitation.id == invitation_id).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if user_id not in {invitation.sender_id, invitation.receiver_id}:
        raise HTTPException(status_code=403, detail="Not allowed to view this invitation")
    return TeamInvitationResponse.model_validate(invitation)
