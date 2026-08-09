
"""
Database connection setup

- PostgreSQL database connection
- SQLAlchemy ORM configuration
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.ext.declarative import declarative_base

from app.common.config import settings

import logging

logger = logging.getLogger(__name__)


# ============================================================
# Database URL
# ============================================================

database_url = settings.DATABASE_URL

# SQLAlchemy normally uses psycopg2 for:
# postgresql://...
#
# We are using psycopg v3, so explicitly use:
# postgresql+psycopg://...
#
if database_url.startswith("postgresql://"):
    database_url = database_url.replace(
        "postgresql://",
        "postgresql+psycopg://",
        1
    )


# ============================================================
# Database engine
# ============================================================

engine = create_engine(
    database_url,
    echo=False,
    pool_pre_ping=True,
    connect_args={
        "check_same_thread": False
    } if database_url.startswith("sqlite") else {},
)


# ============================================================
# Session factory
# ============================================================

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


# ============================================================
# Base class for models
# ============================================================

Base = declarative_base()


# ============================================================
# Database dependency
# ============================================================

def get_db() -> Session:
    """
    Dependency for FastAPI routes.

    Creates a database session per request
    and closes it after the request.
    """
    db = SessionLocal()

    try:
        yield db

    except Exception as e:
        logger.error(f"Database error: {e}")
        raise

    finally:
        db.close()


# ============================================================
# Initialize database
# ============================================================

def init_db():
    """
    Create all database tables.

    All imported SQLAlchemy models will be created
    if they do not already exist.
    """
    try:
        Base.metadata.create_all(bind=engine)

        logger.info("✅ Database tables created/verified")
        return True

    except Exception as e:
        logger.error(f"❌ Database init failed: {e}")
        return False
