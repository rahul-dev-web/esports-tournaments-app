"""
FILE: backend/app/users/router.py
API Router for user endpoints.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.common.deps import current_user_id
from app.users.schemas import (
    UserPublicProfileResponse,
    UserProfileResponse,
    UpdateUserProfileRequest,
    UpdatePhotoRequest,
    UpdateSuccessResponse,
)
from app.users.service import UserService
from app.users.repository import UserRepository


logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================
# GET PROFILE
# ============================================================

@router.get(
    "/profile",
    response_model=UserProfileResponse,
    tags=["users"],
    summary="Get current user profile",
)
async def get_profile(
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """Get current user's profile"""

    profile, error = UserService.get_user_profile(db, user_id)

    if error:
        logger.warning(
            f"Failed to get profile for user {user_id}: {error}"
        )
        raise HTTPException(
            status_code=404,
            detail=error,
        )

    return profile


# ============================================================
# GET OTHER USER'S PROFILE (Public)
# ============================================================

@router.get(
    "/{username}",
    tags=["users"],
    summary="Get public user profile",
)
async def get_user_by_username(
    username: str,
    db: Session = Depends(get_db),
):
    """Get public profile of another user"""

    user = UserRepository.get_user_by_username(
        db,
        username,
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    return UserPublicProfileResponse.model_validate(user)


# ============================================================
# UPDATE PROFILE
# ============================================================

@router.patch(
    "/profile",
    response_model=UpdateSuccessResponse,
    tags=["users"],
    summary="Update user profile",
)
async def update_profile(
    update_data: UpdateUserProfileRequest,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """Update user profile"""

    profile, error = UserService.update_profile(
        db,
        user_id,
        update_data,
    )

    if error:
        logger.warning(
            f"Failed to update profile for user {user_id}: {error}"
        )
        raise HTTPException(
            status_code=400,
            detail=error,
        )

    if profile is None:
        logger.error(
            f"Profile update returned no data for user {user_id}"
        )
        raise HTTPException(
            status_code=500,
            detail="Failed to update profile",
        )

    return UpdateSuccessResponse(
        message="Profile updated successfully",
        data=profile,
    )


# ============================================================
# UPDATE PROFILE PHOTO
# ============================================================

@router.post(
    "/profile/photo",
    response_model=UpdateSuccessResponse,
    tags=["users"],
    summary="Update profile photo",
)
async def update_profile_photo(
    request: UpdatePhotoRequest,
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """Update profile photo"""

    user = UserRepository.update_photo_url(
        db,
        user_id,
        request.photo_url,
    )

    if not user:
        raise HTTPException(
            status_code=400,
            detail="Failed to update photo",
        )

    profile = UserProfileResponse.model_validate(user)

    return UpdateSuccessResponse(
        message="Photo updated successfully",
        data=profile,
    )


# ============================================================
# SEARCH USERS
# ============================================================

@router.get(
    "/search",
    tags=["users"],
    summary="Search users",
)
async def search_users(
    q: str = Query(
        ...,
        min_length=2,
        description="Search query",
    ),
    limit: int = Query(
        10,
        le=50,
        description="Max results",
    ),
    user_id: str = Depends(current_user_id),
    db: Session = Depends(get_db),
):
    """Search for users by username or name"""

    results, error = UserService.search_users_for_team(
        db,
        q,
        limit,
    )

    if error:
        raise HTTPException(
            status_code=400,
            detail=error,
        )

    return {
        "results": results,
        "total": len(results),
    }


# ============================================================
# HEALTH CHECK
# ============================================================

@router.get(
    "/health",
    tags=["users"],
    summary="Health check",
)
async def health():
    """Check if users API is working"""

    return {
        "status": "ok",
        "service": "users-api",
    }
