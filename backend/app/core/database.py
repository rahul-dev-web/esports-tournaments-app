"""Database connection setup for SQLAlchemy-backed local development."""

from __future__ import annotations

import logging
from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from app.common.config import settings


logger = logging.getLogger(__name__)


engine = create_engine(
    settings.DATABASE_URL,
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
