"""
FILE: backend/app/users/service.py
Service layer for user business logic.
COPY THIS FILE AS-IS
"""

import logging
import re
from sqlalchemy.orm import Session
from app.core.models import User
from app.users.repository import UserRepository
from app.users.schemas import UpdateUserProfileRequest, UserProfileResponse

logger = logging.getLogger(__name__)


class UserService:
    """Business logic for user operations"""

    @staticmethod
    def validate_username(username: str) -> tuple[bool, str]:
        """
        Validate username format.
        Rules: 3-20 chars, alphanumeric + underscore/hyphen, start with letter
        """
        if not username:
            return False, "Username is required"
        
        if len(username) < 3:
            return False, "Username must be at least 3 characters"
        
        if len(username) > 20:
            return False, "Username must be at most 20 characters"
        
        if not username[0].isalpha():
            return False, "Username must start with a letter"
        
        pattern = r'^[a-zA-Z][a-zA-Z0-9_-]*$'
        if not re.match(pattern, username):
            return False, "Username can only contain letters, numbers, underscores, and hyphens"
        
        return True, ""

    @staticmethod
    def validate_email(email: str) -> tuple[bool, str]:
        """Validate email format"""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if re.match(pattern, email):
            return True, ""
        return False, "Invalid email format"

    @staticmethod
    def validate_bio(bio: str) -> tuple[bool, str]:
        """Validate bio length"""
        if len(bio) > 500:
            return False, "Bio must be at most 500 characters"
        return True, ""

    @staticmethod
    def get_user_profile(db: Session, user_id: str) -> tuple[UserProfileResponse | None, str]:
        """Get user profile"""
        try:
            user = UserRepository.get_user_by_id(db, user_id)
            
            if not user:
                return None, "User not found"
            
            if not user.is_active:
                return None, "User account is deactivated"
            
            response = UserProfileResponse.from_orm(user)
            return response, ""
            
        except Exception as e:
            logger.error(f"Error getting user profile: {e}")
            return None, "Failed to get user profile"

    @staticmethod
    def create_user_on_first_login(
        db: Session,
        google_id: str,
        email: str,
        name: str,
        username: str
    ) -> tuple[UserProfileResponse | None, str]:
        """Create user account on first Google login"""
        try:
            is_valid, error_msg = UserService.validate_username(username)
            if not is_valid:
                return None, error_msg
            
            existing = UserRepository.get_user_by_username(db, username)
            if existing:
                return None, "Username already taken"
            
            existing_email = UserRepository.get_user_by_email(db, email)
            if existing_email:
                return None, "Email already registered"
            
            user = UserRepository.create_user(
                db,
                google_id=google_id,
                email=email,
                name=name,
                username=username
            )
            
            if not user:
                return None, "Failed to create user"
            
            response = UserProfileResponse.from_orm(user)
            return response, ""
            
        except Exception as e:
            logger.error(f"Error creating user on first login: {e}")
            return None, "Failed to create account"

    @staticmethod
    def update_profile(
        db: Session,
        user_id: str,
        update_data: UpdateUserProfileRequest
    ) -> tuple[UserProfileResponse | None, str]:
        """Update user profile"""
        try:
            user = UserRepository.get_user_by_id(db, user_id)
            if not user:
                return None, "User not found"
            
            update_fields = update_data.model_dump(exclude_unset=True)
            username = update_fields.get("username")
            bio = update_fields.get("bio")
            
            if username is not None:
                is_valid, error_msg = UserService.validate_username(username)
                if not is_valid:
                    return None, error_msg
                
                existing = UserRepository.get_user_by_username(db, username)
                if existing and existing.id != user_id:
                    return None, "Username already taken"
            
            if bio is not None:
                is_valid, error_msg = UserService.validate_bio(bio)
                if not is_valid:
                    return None, error_msg
            
            updated_user = UserRepository.update_user_profile(db, user_id, update_data)
            
            if not updated_user:
                return None, "Failed to update profile"
            
            response = UserProfileResponse.from_orm(updated_user)
            return response, ""
            
        except Exception as e:
            logger.error(f"Error updating profile: {e}")
            return None, "Failed to update profile"

    @staticmethod
    def search_users_for_team(
        db: Session,
        query: str,
        limit: int = 10
    ) -> tuple[list[dict], str]:
        """Search users to add to team"""
        try:
            if len(query) < 2:
                return [], "Search query too short"
            
            users = UserRepository.search_users(db, query, limit)
            
            result = [
                {
                    "id": u.id,
                    "username": u.username,
                    "name": u.name,
                    "photo_url": u.photo_url
                }
                for u in users
            ]
            
            return result, ""
            
        except Exception as e:
            logger.error(f"Error searching users: {e}")
            return [], "Failed to search users"