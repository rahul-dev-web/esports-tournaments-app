"""Database connection setup for SQLAlchemy-backed local development."""

from __future__ import annotations

import logging
from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from app.common.config import settings


logger = logging.getLogger(__name__)


def build_database_url(raw_url: str) -> str:
    if raw_url.startswith("postgresql://"):
        try:
            import psycopg  # noqa: F401
            return raw_url.replace("postgresql://", "postgresql+psycopg://", 1)
        except ImportError:
            return raw_url
    return raw_url


engine = create_engine(
    build_database_url(settings.DATABASE_URL),
    echo=False,
    pool_pre_ping=True,
    connect_args={"check_same_thread": False} if settings.DATABASE_URL.startswith("sqlite") else {},
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> bool:
    """
    Create local development tables when using SQLite.

    Production uses the Supabase SQL schema as the source of truth, so this is
    intentionally a no-op for non-SQLite databases.
    """

    try:
        if not settings.DATABASE_URL.startswith("sqlite"):
            logger.info("Skipping SQLAlchemy table bootstrap for non-SQLite DATABASE_URL")
            return True

        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created/verified")
        return True
    except Exception as exc:
        logger.exception("Database init failed: %s", exc)
        return False
