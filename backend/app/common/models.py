"""Shared request/response schemas for the backend API."""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class Role(str, Enum):
    user = "user"
    admin = "admin"


class RegistrationPolicy(str, Enum):
    individual = "individual_ads"
    captain = "captain_ads"


class TournamentStatus(str, Enum):
    draft = "draft"
    published = "published"
    closed = "closed"


class TournamentType(str, Enum):
    solo = "solo"
    duo = "duo"
    squad = "squad"
    custom = "custom"


class RegistrationStatus(str, Enum):
    pending = "pending"
    ad_verification = "ad_verification"
    registered = "registered"
    rejected = "rejected"
    expired = "expired"


class InvitationStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    expired = "expired"
    cancelled = "cancelled"


class UserProfile(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    name: str
    username: str
    role: Role = Role.user
    bio: str | None = ""
    country: str | None = ""
    state: str | None = ""
    city: str | None = ""
    photo_url: str | None = None
    social_links: dict[str, Any] = Field(default_factory=dict)
    preferred_game: str | None = ""
    in_game_uid: str | None = None
    created_at: datetime
    updated_at: datetime


class UserProfileUpdate(BaseModel):
    name: str | None = None
    username: str | None = None
    bio: str | None = None
    country: str | None = None
    state: str | None = None
    city: str | None = None
    photo_url: str | None = None
    preferred_game: str | None = None
    social_links: dict[str, Any] | None = None


class TeamCreate(BaseModel):
    name: str = Field(min_length=2, max_length=60)
    game: str
    is_private: bool = False
    logo_url: str | None = None


class Team(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    game: str
    captain_id: str
    member_ids: list[str] = Field(default_factory=list)
    is_private: bool = False
    logo_url: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class TournamentCreate(BaseModel):
    name: str = Field(min_length=3, max_length=120)
    game: str
    mode: str
    tournament_type: TournamentType = TournamentType.custom
    starts_at: datetime
    entry_requirement: str | None = ""
    reward: str | None = ""
    status: TournamentStatus = TournamentStatus.draft
    total_slots: int = Field(gt=0)
    registered_teams: int = 0
    team_size: int = Field(default=1, ge=1)
    ads_required: int = Field(default=0, ge=0)
    policy: RegistrationPolicy = RegistrationPolicy.individual


class Tournament(TournamentCreate):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    updated_at: datetime


class AdCompletion(BaseModel):
    registration_id: str
    viewer_id: str
    session_token: str
    provider: str = "admob"
    provider_event_id: str | None = None
    verification_token: str | None = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "registration_id": "reg-123",
                "viewer_id": "user-456",
                "session_token": "ad-session-token",
                "provider": "admob",
                "provider_event_id": "evt-123",
            }
        }
    )


class RegistrationStatusDetail(BaseModel):
    registration_id: str
    status: str
    ads_required: int
    ads_completed: int
    members_completed: list[str]
    is_complete: bool
    slot: Optional[int] = None


class Registration(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tournament_id: str
    team_id: str
    captain_id: str
    status: RegistrationStatus = RegistrationStatus.pending
    ads_required: int
    ads_completed: int = 0
    completed_by: list[str] = Field(default_factory=list)
    slot: int | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    title: str
    body: str
    notification_type: str = "general"
    data: dict[str, Any] = Field(default_factory=dict)
    read_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class DeviceTokenCreate(BaseModel):
    token: str = Field(min_length=16, max_length=1000)
    platform: str = Field(min_length=2, max_length=20)
    device_name: str | None = Field(default=None, max_length=255)


class DeviceTokenResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    token: str
    platform: str
    device_name: str | None = None
    is_active: bool
    last_seen_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class TeamInvitationCreate(BaseModel):
    receiver_id: str
    message: str | None = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "receiver_id": "user-123",
                "message": "We need a good player for squad",
            }
        }
    )


class TeamInvitationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    team_id: str
    sender_id: str
    receiver_id: str
    status: InvitationStatus
    message: str | None = None
    expires_at: datetime
    created_at: datetime
    updated_at: datetime


class InvitationActionRequest(BaseModel):
    action: str

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "action": "accept",
            }
        }
    )


class TeamInvitationList(BaseModel):
    id: str
    team: dict[str, Any]
    sender: dict[str, Any]
    status: InvitationStatus
    message: str | None = None
    created_at: datetime
    expires_at: datetime


class SettingCreate(BaseModel):
    key: str = Field(..., min_length=1, max_length=100)
    value: Any
    description: str | None = None
    value_type: str = Field(default="string")


class SettingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    key: str
    value: Any
    description: str | None = None
    value_type: str
    updated_at: datetime
    updated_by: str | None = None


class SettingsDict(BaseModel):
    ads_per_registration: int = 2
    registration_policy: str = "individual_ads"
    max_team_size: int = 5
    tournament_registration_timeout: int = 24
    reward_amount: int = 1000
    reward_currency: str = "INR"
