"""SQLAlchemy mappings for the authoritative Supabase schema.

IDs are represented as UUID values in PostgreSQL and transparently as strings in
the local SQLite test database.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum
from typing import Any

from sqlalchemy import Boolean, DateTime, Enum as SAEnum, ForeignKey, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import TypeDecorator

from app.core.database import Base


class GUID(TypeDecorator):
    impl = String(36)
    cache_ok = True
    def load_dialect_impl(self, dialect):
        from sqlalchemy.dialects.postgresql import UUID
        return dialect.type_descriptor(UUID(as_uuid=False) if dialect.name == "postgresql" else String(36))
    def process_bind_param(self, value, dialect):
        return str(value) if value is not None else None
    def process_result_value(self, value, dialect):
        return str(value) if value is not None else None


class RoleEnum(str, Enum): user = "user"; admin = "admin"
class TournamentStatusEnum(str, Enum): draft = "draft"; published = "published"; closed = "closed"
class RegistrationStatusEnum(str, Enum): pending = "pending"; ad_verification = "ad_verification"; registered = "registered"; rejected = "rejected"; expired = "expired"
class RegistrationPolicyEnum(str, Enum): individual_ads = "individual_ads"; captain_ads = "captain_ads"
class TournamentTypeEnum(str, Enum): solo = "solo"; duo = "duo"; squad = "squad"; custom = "custom"
class InvitationStatusEnum(str, Enum): pending = "pending"; accepted = "accepted"; rejected = "rejected"; expired = "expired"; cancelled = "cancelled"


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class User(TimestampMixin, Base):
    __tablename__ = "profiles"
    id: Mapped[str] = mapped_column(GUID(), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
    email: Mapped[str] = mapped_column(String(320), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(100), default="", nullable=False)
    username: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    bio: Mapped[str] = mapped_column(Text, default="", nullable=False)
    country: Mapped[str] = mapped_column(String(100), default="", nullable=False)
    state: Mapped[str] = mapped_column(String(100), default="", nullable=False)
    city: Mapped[str] = mapped_column(String(100), default="", nullable=False)
    photo_url: Mapped[str | None] = mapped_column(String(1000))
    social_links: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    preferred_game: Mapped[str] = mapped_column(String(100), default="", nullable=False)
    in_game_uid: Mapped[str | None] = mapped_column(String(100), nullable=True)
    role: Mapped[RoleEnum] = mapped_column(SAEnum(RoleEnum, name="app_role"), default=RoleEnum.user, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    team_memberships: Mapped[list["TeamMember"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    teams: Mapped[list["Team"]] = relationship(back_populates="captain", foreign_keys="Team.captain_id")


class Team(TimestampMixin, Base):
    __tablename__ = "teams"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    game: Mapped[str] = mapped_column(String(100), nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(1000))
    captain_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id"), nullable=False)
    is_private: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    captain: Mapped[User] = relationship(back_populates="teams", foreign_keys=[captain_id])
    members: Mapped[list["TeamMember"]] = relationship(back_populates="team", cascade="all, delete-orphan")
    invitations: Mapped[list["TeamInvitation"]] = relationship(back_populates="team", cascade="all, delete-orphan")

    @property
    def member_ids(self): return [m.user_id for m in self.members]


class TeamMember(Base):
    __tablename__ = "team_members"
    team_id: Mapped[str] = mapped_column(GUID(), ForeignKey("teams.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    team: Mapped[Team] = relationship(back_populates="members")
    user: Mapped[User] = relationship(back_populates="team_memberships")


class TeamInvitation(TimestampMixin, Base):
    __tablename__ = "team_invitations"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    team_id: Mapped[str] = mapped_column(GUID(), ForeignKey("teams.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id"))
    receiver_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id"))
    status: Mapped[InvitationStatusEnum] = mapped_column(SAEnum(InvitationStatusEnum, name="invitation_status"), default=InvitationStatusEnum.pending, nullable=False)
    message: Mapped[str | None] = mapped_column(Text)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    team: Mapped[Team] = relationship(back_populates="invitations")
    sender: Mapped[User] = relationship(foreign_keys=[sender_id])
    receiver: Mapped[User] = relationship(foreign_keys=[receiver_id])


class Tournament(TimestampMixin, Base):
    __tablename__ = "tournaments"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    game: Mapped[str] = mapped_column(String(100), nullable=False)
    mode: Mapped[str] = mapped_column(String(50), nullable=False)
    tournament_type: Mapped[TournamentTypeEnum] = mapped_column(SAEnum(TournamentTypeEnum, name="tournament_type"), default=TournamentTypeEnum.custom, nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    entry_requirement: Mapped[str] = mapped_column(String(255), default="", nullable=False)
    reward: Mapped[str] = mapped_column(String(255), default="", nullable=False)
    status: Mapped[TournamentStatusEnum] = mapped_column(SAEnum(TournamentStatusEnum, name="tournament_status"), default=TournamentStatusEnum.draft, nullable=False)
    total_slots: Mapped[int] = mapped_column(Integer, nullable=False)
    registered_teams: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    team_size: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    ads_required: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    policy: Mapped[RegistrationPolicyEnum] = mapped_column(SAEnum(RegistrationPolicyEnum, name="registration_policy"), default=RegistrationPolicyEnum.individual_ads, nullable=False)
    registrations: Mapped[list["Registration"]] = relationship(back_populates="tournament", cascade="all, delete-orphan")


class Registration(TimestampMixin, Base):
    __tablename__ = "tournament_registrations"
    __table_args__ = (
        UniqueConstraint("tournament_id", "team_id", name="uq_registration_tournament_team"),
        UniqueConstraint("tournament_id", "slot", name="uq_registration_tournament_slot"),
    )
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    tournament_id: Mapped[str] = mapped_column(GUID(), ForeignKey("tournaments.id"), nullable=False, index=True)
    team_id: Mapped[str] = mapped_column(GUID(), ForeignKey("teams.id"), nullable=False, index=True)
    captain_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id"), nullable=False)
    status: Mapped[RegistrationStatusEnum] = mapped_column(SAEnum(RegistrationStatusEnum, name="registration_status"), default=RegistrationStatusEnum.pending, nullable=False)
    policy: Mapped[RegistrationPolicyEnum] = mapped_column(SAEnum(RegistrationPolicyEnum, name="registration_policy"), nullable=False)
    ads_required: Mapped[int] = mapped_column(Integer, nullable=False)
    ads_completed: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed_by: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    slot: Mapped[int | None] = mapped_column(Integer)
    tournament: Mapped[Tournament] = relationship(back_populates="registrations", foreign_keys=[tournament_id])
    team: Mapped[Team] = relationship(foreign_keys=[team_id])
    captain: Mapped[User] = relationship(foreign_keys=[captain_id])

    @property
    def user_id(self) -> str:
        return self.captain_id

    @user_id.setter
    def user_id(self, value: str) -> None:
        self.captain_id = value

    @property
    def slot_assigned(self) -> bool:
        return self.slot is not None

    @slot_assigned.setter
    def slot_assigned(self, value: bool) -> None:
        if not value:
            self.slot = None

    @property
    def slot_number(self) -> int | None:
        return self.slot

    @slot_number.setter
    def slot_number(self, value: int | None) -> None:
        self.slot = value


class AdSession(TimestampMixin, Base):
    __tablename__ = "ad_sessions"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    registration_id: Mapped[str] = mapped_column(GUID(), ForeignKey("tournament_registrations.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    session_token: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    provider: Mapped[str] = mapped_column(String(30), default="admob", nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reward_ad_events: Mapped[list["RewardAdEvent"]] = relationship(back_populates="session", cascade="all, delete-orphan")


class RewardAdEvent(Base):
    __tablename__ = "reward_ad_events"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    ad_session_id: Mapped[str] = mapped_column(GUID(), ForeignKey("ad_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    registration_id: Mapped[str] = mapped_column(GUID(), ForeignKey("tournament_registrations.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id"), nullable=False)
    provider: Mapped[str] = mapped_column(String(30), nullable=False)
    provider_event_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    verified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    session: Mapped[AdSession] = relationship(back_populates="reward_ad_events")


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class Settings(Base):
    __tablename__ = "settings"
    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    value: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    value_type: Mapped[str] = mapped_column(String(20), default="string", nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    updated_by: Mapped[str | None] = mapped_column(GUID(), ForeignKey("profiles.id"))


class DeviceToken(Base):
    __tablename__ = "device_tokens"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(GUID(), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    token: Mapped[str] = mapped_column(String(1000), unique=True, nullable=False)
    platform: Mapped[str] = mapped_column(String(20), nullable=False)
    device_name: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[str] = mapped_column(GUID(), primary_key=True, default=lambda: str(uuid.uuid4()))
    actor_id: Mapped[str | None] = mapped_column(GUID(), ForeignKey("profiles.id"))
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    entity: Mapped[str] = mapped_column(String(100), nullable=False)
    entity_id: Mapped[str | None] = mapped_column(GUID())
    metadata_json: Mapped[dict[str, Any] | None] = mapped_column("metadata", JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
