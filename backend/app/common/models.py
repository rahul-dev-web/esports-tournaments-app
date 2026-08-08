from datetime import datetime
from enum import Enum
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


class RegistrationStatus(str, Enum):
    pending = "pending"
    ad_verification = "ad_verification"
    registered = "registered"
    rejected = "rejected"


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
    preferred_game: str | None = ""
    created_at: datetime = Field(default_factory=datetime.utcnow)


class UserProfileUpdate(BaseModel):
    name: str | None = None
    username: str | None = None
    bio: str | None = None
    country: str | None = None
    state: str | None = None
    city: str | None = None
    photo_url: str | None = None
    preferred_game: str | None = None


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
    member_ids: list[str] = []
    is_private: bool = False
    logo_url: str | None = None


class TournamentCreate(BaseModel):
    name: str = Field(min_length=3, max_length=120)
    game: str
    mode: str
    starts_at: datetime
    entry_requirement: str | None = "Watch required ads"
    reward: str | None = None
    total_slots: int = Field(gt=0)
    ads_required: int = Field(default=1, ge=0)
    policy: RegistrationPolicy = RegistrationPolicy.individual


class Tournament(TournamentCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    status: TournamentStatus = TournamentStatus.draft
    registered_teams: int = 0


class AdCompletion(BaseModel):
    registration_id: str
    viewer_id: str
    verification_token: str = Field(min_length=8)


class Registration(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    tournament_id: str
    team_id: str
    captain_id: str
    status: RegistrationStatus = RegistrationStatus.pending
    ads_required: int
    ads_completed: int = 0
    completed_by: list[str] = []
    slot: int | None = None
