"""Business logic for profile operations."""

from __future__ import annotations

import logging
import re

from sqlalchemy.orm import Session

from app.users.repository import UserRepository
from app.users.schemas import UpdateUserProfileRequest, UserProfileResponse


logger = logging.getLogger(__name__)


class UserService:
    @staticmethod
    def validate_username(username: str) -> tuple[bool, str]:
        if not username:
            return False, "Username is required"
        if len(username) < 3:
            return False, "Username must be at least 3 characters"
        if len(username) > 20:
            return False, "Username must be at most 20 characters"
        if not username[0].isalpha():
            return False, "Username must start with a letter"
        if not re.match(r"^[a-zA-Z][a-zA-Z0-9_-]*$", username):
            return False, "Username can only contain letters, numbers, underscores, and hyphens"
        return True, ""

    @staticmethod
    def get_user_profile(db: Session, user_id: str) -> tuple[UserProfileResponse | None, str]:
        user = UserRepository.get_user_by_id(db, user_id)
        if not user:
            return None, "User not found"
        if not user.is_active:
            return None, "User account is deactivated"
        return UserProfileResponse.model_validate(user), ""

    @staticmethod
    def update_profile(
        db: Session,
        user_id: str,
        update_data: UpdateUserProfileRequest,
    ) -> tuple[UserProfileResponse | None, str]:
        user = UserRepository.get_user_by_id(db, user_id)
        if not user:
            return None, "User not found"

        update_fields = update_data.model_dump(exclude_unset=True)
        username = update_fields.get("username")
        bio = update_fields.get("bio")

        if username is not None:
            valid, error = UserService.validate_username(username)
            if not valid:
                return None, error
            existing = UserRepository.get_user_by_username(db, username)
            if existing and existing.id != user_id:
                return None, "Username already taken"

        if bio is not None and len(bio) > 500:
            return None, "Bio must be at most 500 characters"

        updated_user = UserRepository.update_user_profile(db, user_id, update_data)
        if not updated_user:
            return None, "Failed to update profile"

        return UserProfileResponse.model_validate(updated_user), ""

    @staticmethod
    def search_users_for_team(db: Session, query: str, limit: int = 10) -> tuple[list[dict], str]:
        if len(query) < 2:
            return [], "Search query too short"

        users = UserRepository.search_users(db, query, limit)
        return (
            [
                {
                    "id": user.id,
                    "username": user.username,
                    "name": user.name,
                    "photo_url": user.photo_url,
                }
                for user in users
            ],
            "",
        )
