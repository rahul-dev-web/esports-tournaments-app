"""
SQLAlchemy ORM Models
- Replace Pydantic models for database
- Persistent storage
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
import uuid
from typing import List

from sqlalchemy import String, Integer, DateTime, Boolean, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

# Enums
class RoleEnum(str, Enum):
    user = "user"
    admin = "admin"

class TournamentStatusEnum(str, Enum):
    draft = "draft"
    published = "published"
    closed = "closed"

class RegistrationStatusEnum(str, Enum):
    pending = "pending"
    ad_verification = "ad_verification"
    registered = "registered"
    rejected = "rejected"

class RegistrationPolicyEnum(str, Enum):
    individual_ads = "individual_ads"
    captain_ads = "captain_ads"

class InvitationStatusEnum(str, Enum):
    """Status of team invitation"""
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    expired = "expired"
    cancelled = "cancelled"


# Database Models

class User(Base):
    """User model - database table"""
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    google_id: Mapped[str] = mapped_column(String, unique=True, index=True)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    name: Mapped[str] = mapped_column(String)
    username: Mapped[str] = mapped_column(String, unique=True, index=True)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    country: Mapped[str | None] = mapped_column(String, nullable=True)
    state: Mapped[str | None] = mapped_column(String, nullable=True)
    city: Mapped[str | None] = mapped_column(String, nullable=True)
    photo_url: Mapped[str | None] = mapped_column(String, nullable=True)
    preferred_game: Mapped[str | None] = mapped_column(String, nullable=True)
    role: Mapped[RoleEnum] = mapped_column(SQLEnum(RoleEnum), default=RoleEnum.user)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    teams: Mapped[List["Team"]] = relationship(back_populates="captain")
    registrations: Mapped[List["Registration"]] = relationship(back_populates="user")
    sent_invitations: Mapped[List["TeamInvitation"]] = relationship(foreign_keys="TeamInvitation.sender_id", back_populates="sender")
    received_invitations: Mapped[List["TeamInvitation"]] = relationship(foreign_keys="TeamInvitation.receiver_id", back_populates="receiver")

class Team(Base):
    """Team model - database table"""
    __tablename__ = "teams"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String, index=True)
    game: Mapped[str] = mapped_column(String)
    logo_url: Mapped[str | None] = mapped_column(String, nullable=True)
    captain_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    is_private: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    captain: Mapped["User"] = relationship(back_populates="teams")
    members: Mapped[List["TeamMember"]] = relationship(back_populates="team")
    registrations: Mapped[List["Registration"]] = relationship(back_populates="team")
    invitations: Mapped[List["TeamInvitation"]] = relationship(back_populates="team")

    @property
    def member_ids(self) -> List[str]:
        return [member.user_id for member in self.members]

class TeamMember(Base):
    """Team member mapping"""
    __tablename__ = "team_members"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    team_id: Mapped[str] = mapped_column(String, ForeignKey("teams.id"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    team: Mapped["Team"] = relationship(back_populates="members")

class Tournament(Base):
    """Tournament model - database table"""
    __tablename__ = "tournaments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String, index=True)
    game: Mapped[str] = mapped_column(String)
    mode: Mapped[str] = mapped_column(String)
    starts_at: Mapped[datetime] = mapped_column(DateTime)
    entry_requirement: Mapped[str | None] = mapped_column(String, nullable=True)
    reward: Mapped[str | None] = mapped_column(String, nullable=True)
    total_slots: Mapped[int] = mapped_column(Integer)
    registered_teams: Mapped[int] = mapped_column(Integer, default=0)
    ads_required: Mapped[int] = mapped_column(Integer, default=1)
    policy: Mapped[RegistrationPolicyEnum] = mapped_column(SQLEnum(RegistrationPolicyEnum), default=RegistrationPolicyEnum.individual_ads)
    status: Mapped[TournamentStatusEnum] = mapped_column(SQLEnum(TournamentStatusEnum), default=TournamentStatusEnum.draft)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    registrations: Mapped[List["Registration"]] = relationship(back_populates="tournament")

class Registration(Base):
    """Tournament registration"""
    __tablename__ = "registrations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tournament_id: Mapped[str] = mapped_column(String, ForeignKey("tournaments.id"))
    team_id: Mapped[str] = mapped_column(String, ForeignKey("teams.id"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    status: Mapped[RegistrationStatusEnum] = mapped_column(SQLEnum(RegistrationStatusEnum), default=RegistrationStatusEnum.pending)
    ads_required: Mapped[int] = mapped_column(Integer)
    ads_completed: Mapped[int] = mapped_column(Integer, default=0)
    completed_by: Mapped[str | None] = mapped_column(String, nullable=True)
    slot_assigned: Mapped[bool] = mapped_column(Boolean, default=False)
    slot_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    tournament: Mapped["Tournament"] = relationship(back_populates="registrations")
    team: Mapped["Team"] = relationship(back_populates="registrations")
    user: Mapped["User"] = relationship(back_populates="registrations")

class TeamInvitation(Base):
    """
    Team member invitation system.
    - Captain sends invitations
    - Users accept or reject invitations
    - Invitation history is stored
    """
    __tablename__ = "team_invitations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    team_id: Mapped[str] = mapped_column(String, ForeignKey("teams.id"), index=True)
    sender_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    receiver_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    status: Mapped[InvitationStatusEnum] = mapped_column(SQLEnum(InvitationStatusEnum), default=InvitationStatusEnum.pending, index=True)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    team: Mapped["Team"] = relationship(back_populates="invitations")
    sender: Mapped["User"] = relationship(foreign_keys=[sender_id], back_populates="sent_invitations")
    receiver: Mapped["User"] = relationship(foreign_keys=[receiver_id], back_populates="received_invitations")
