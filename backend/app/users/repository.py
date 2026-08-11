"""Repository layer for profile operations."""

from __future__ import annotations

import logging

from sqlalchemy.orm import Session

from app.core.models import User


logger = logging.getLogger(__name__)


class UserRepository:
    @staticmethod
    def get_user_by_id(db: Session, user_id: str) -> User | None:
        return db.query(User).filter(User.id == user_id).first()

    @staticmethod
    def get_user_by_username(db: Session, username: str) -> User | None:
        return db.query(User).filter(User.username == username).first()

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> User | None:
        return db.query(User).filter(User.email == email).first()

    @staticmethod
    def create_user(
        db: Session,
        user_id: str,
        email: str,
        name: str,
        username: str,
    ) -> User | None:
        try:
            user = User(id=user_id, email=email, name=name, username=username)
            db.add(user)
            db.commit()
            db.refresh(user)
            return user
        except Exception as exc:
            db.rollback()
            logger.error("Error creating user: %s", exc)
            return None

    @staticmethod
    def update_user_profile(db: Session, user_id: str, update_data) -> User | None:
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return None

            for field, value in update_data.model_dump(exclude_unset=True).items():
                if hasattr(user, field) and field not in {"id", "email", "role", "created_at"}:
                    setattr(user, field, value)

            db.commit()
            db.refresh(user)
            return user
        except Exception as exc:
            db.rollback()
            logger.error("Error updating user profile: %s", exc)
            return None

    @staticmethod
    def update_photo_url(db: Session, user_id: str, photo_url: str) -> User | None:
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return None

            user.photo_url = photo_url
            db.commit()
            db.refresh(user)
            return user
        except Exception as exc:
            db.rollback()
            logger.error("Error updating photo: %s", exc)
            return None

    @staticmethod
    def search_users(db: Session, query: str, limit: int = 10) -> list[User]:
        pattern = f"%{query}%"
        return (
            db.query(User)
            .filter((User.username.ilike(pattern)) | (User.name.ilike(pattern)))
            .limit(limit)
            .all()
        )
