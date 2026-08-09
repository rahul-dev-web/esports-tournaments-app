
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.common.config import settings
from app.core.database import init_db
from app.core import models  # Import models to register them with SQLAlchemy

# Import routers
from app.auth.router import router as auth_router
from app.users.router import router as users_router
from app.teams.router import router as teams_router
from app.tournaments.router import router as tournaments_router
from app.registrations.router import router as registrations_router
from app.admin.router import router as admin_router

import logging

logger = logging.getLogger(__name__)
app = FastAPI(
    title="eSports Tournament API",
    description="Tournament management platform",
    version="0.1.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(
    auth_router,
    prefix="/api/auth",
    tags=["auth"]
)

app.include_router(
    users_router,
    prefix="/api/users",
    tags=["users"]
)

app.include_router(
    teams_router,
    prefix="/api/teams",
    tags=["teams"]
)

app.include_router(
    tournaments_router,
    prefix="/api/tournaments",
    tags=["tournaments"]
)

app.include_router(
    registrations_router,
    prefix="/api/registrations",
    tags=["registrations"]
)

app.include_router(
    admin_router,
    prefix="/api/admin",
    tags=["admin"]
)


# Database initialization
@app.on_event("startup")
async def startup():
    logger.info("Starting application...")

    if init_db():
        logger.info("✅ Database initialized")
    else:
        logger.error("❌ Database initialization failed")


# Health check
@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "arenahub-api"
    }
