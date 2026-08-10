"""
FILE: backend/app/users/schemas.py
Pydantic schemas for user API requests and responses.
COPY THIS FILE AS-IS
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ============================================================
# REQUEST SCHEMAS (Data coming FROM client TO server)
# ============================================================

class UpdateUserProfileRequest(BaseModel):
    """Schema for updating user profile"""
    username: Optional[str] = Field(None, min_length=3, max_length=20)
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    bio: Optional[str] = Field(None, max_length=500)
    country: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    city: Optional[str] = Field(None, max_length=100)
    preferred_game: Optional[str] = Field(None, max_length=100)

    class Config:
        extra = "ignore"


class UpdatePhotoRequest(BaseModel):
    """Schema for profile photo update"""
    photo_url: str = Field(..., min_length=1, max_length=1000)
    
    class Config:
        extra = "ignore"


# ============================================================
# RESPONSE SCHEMAS (Data sent FROM server TO client)
# ============================================================

class UserProfileResponse(BaseModel):
    """Complete user profile response"""
    id: str
    name: str
    username: str
    email: str
    bio: Optional[str]
    country: Optional[str]
    state: Optional[str]
    city: Optional[str]
    photo_url: Optional[str]
    preferred_game: Optional[str]
    
    role: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserPublicProfileResponse(BaseModel):
    """Public profile - limited info"""
    id: str
    username: str
    name: str
    bio: Optional[str]
    country: Optional[str]
    city: Optional[str]
    photo_url: Optional[str]
    preferred_game: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class UpdateSuccessResponse(BaseModel):
    """Generic success response"""
    message: str
    data: UserProfileResponse


class ErrorResponse(BaseModel):
    """Generic error response"""
    error: str
    detail: Optional[str] = None