"""
FILE: backend/app/users/repository.py
Repository layer for user database operations.
COPY THIS FILE AS-IS
"""

import logging
from sqlalchemy.orm import Session
from app.core.models import User

logger = logging.getLogger(__name__)


class UserRepository:
    """Handles all database operations for users"""

    @staticmethod
    def get_user_by_id(db: Session, user_id: str) -> User | None:
        """Get a single user by ID from database"""
        try:
            user = db.query(User).filter(User.id == user_id).first()
            return user
        except Exception as e:
            logger.error(f"Error getting user {user_id}: {e}")
            return None

    @staticmethod
    def get_user_by_username(db: Session, username: str) -> User | None:
        """Get user by username"""
        try:
            user = db.query(User).filter(User.username == username).first()
            return user
        except Exception as e:
            logger.error(f"Error getting user by username {username}: {e}")
            return None

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> User | None:
        """Get user by email"""
        try:
            user = db.query(User).filter(User.email == email).first()
            return user
        except Exception as e:
            logger.error(f"Error getting user by email {email}: {e}")
            return None

    @staticmethod
    def get_user_by_google_id(db: Session, google_id: str) -> User | None:
        """Get user by Google ID"""
        try:
            user = db.query(User).filter(User.google_id == google_id).first()
            return user
        except Exception as e:
            logger.error(f"Error getting user by google_id {google_id}: {e}")
            return None

    @staticmethod
    def create_user(
        db: Session,
        google_id: str,
        email: str,
        name: str,
        username: str
    ) -> User | None:
        """Create a new user in database"""
        try:
            new_user = User(
                google_id=google_id,
                email=email,
                name=name,
                username=username,
                role="user"
            )
            
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            
            logger.info(f"User created: {new_user.id}")
            return new_user
            
        except Exception as e:
            db.rollback()
            logger.error(f"Error creating user: {e}")
            return None

    @staticmethod
    def update_user_profile(db: Session, user_id: str, update_data) -> User | None:
        """Update user profile information"""
        try:
            user = db.query(User).filter(User.id == user_id).first()
            
            if not user:
                logger.warning(f"User {user_id} not found for update")
                return None
            
            update_fields = update_data.model_dump(exclude_unset=True)
            
            for field, value in update_fields.items():
                if value is not None:
                    setattr(user, field, value)
            
            db.commit()
            db.refresh(user)
            
            logger.info(f"User {user_id} profile updated")
            return user
            
        except Exception as e:
            db.rollback()
            logger.error(f"Error updating user profile: {e}")
            return None

    @staticmethod
    def update_photo_url(db: Session, user_id: str, photo_url: str) -> User | None:
        """Update user's profile photo URL"""
        try:
            user = db.query(User).filter(User.id == user_id).first()
            
            if not user:
                return None
            
            user.photo_url = photo_url
            db.commit()
            db.refresh(user)
            
            logger.info(f"Photo updated for user {user_id}")
            return user
            
        except Exception as e:
            db.rollback()
            logger.error(f"Error updating photo: {e}")
            return None

    @staticmethod
    def deactivate_user(db: Session, user_id: str) -> bool:
        """Deactivate a user account"""
        try:
            user = db.query(User).filter(User.id == user_id).first()
            
            if not user:
                return False
            
            user.is_active = False
            db.commit()
            
            logger.info(f"User {user_id} deactivated")
            return True
            
        except Exception as e:
            db.rollback()
            logger.error(f"Error deactivating user: {e}")
            return False

    @staticmethod
    def search_users(db: Session, query: str, limit: int = 10) -> list[User]:
        """Search users by username or name"""
        try:
            search_pattern = f"%{query}%"
            
            users = db.query(User).filter(
                (User.username.ilike(search_pattern)) |
                (User.name.ilike(search_pattern))
            ).limit(limit).all()
            
            return users
            
        except Exception as e:
            logger.error(f"Error searching users: {e}")
            return []