"""Pydantic schemas for profile API requests and responses."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class UpdateUserProfileRequest(BaseModel):
    username: Optional[str] = Field(None, min_length=3, max_length=20)
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    bio: Optional[str] = Field(None, max_length=500)
    country: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    city: Optional[str] = Field(None, max_length=100)
    photo_url: Optional[str] = Field(None, max_length=1000)
    preferred_game: Optional[str] = Field(None, max_length=100)
    social_links: Optional[dict[str, str]] = None
    # The in-game UID may be set once during profile setup, but is immutable
    # after it has been saved. The service layer enforces that rule.
    in_game_uid: Optional[str] = Field(None, min_length=1, max_length=100)

    model_config = ConfigDict(extra="ignore")


class UpdatePhotoRequest(BaseModel):
    photo_url: str = Field(..., min_length=1, max_length=1000)

    model_config = ConfigDict(extra="ignore")


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    username: str
    email: str
    bio: Optional[str] = ""
    country: Optional[str] = ""
    state: Optional[str] = ""
    city: Optional[str] = ""
    photo_url: Optional[str] = None
    preferred_game: Optional[str] = ""
    social_links: dict[str, str] = {}
    in_game_uid: Optional[str] = None
    role: str
    is_active: bool
    created_at: datetime
    updated_at: datetime


class UserPublicProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    username: str
    name: str
    bio: Optional[str] = ""
    country: Optional[str] = ""
    city: Optional[str] = ""
    photo_url: Optional[str] = None
    preferred_game: Optional[str] = ""
    created_at: datetime


class UpdateSuccessResponse(BaseModel):
    message: str
    data: UserProfileResponse
