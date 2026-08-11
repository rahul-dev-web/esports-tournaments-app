from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.common.config import settings
from app.core import models  # noqa: F401  # register SQLAlchemy models
from app.core.database import init_db
from app.admin.router import router as admin_router
from app.ads.router import router as ads_router
from app.auth.router import router as auth_router
from app.registrations.router import router as registrations_router
from app.teams.router import router as teams_router
from app.tournaments.router import router as tournaments_router
from app.users.router import router as users_router


logger = logging.getLogger(__name__)

app = FastAPI(
    title="eSports Tournament API",
    description="Tournament management platform",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
app.include_router(users_router, prefix="/api/users", tags=["users"])
app.include_router(teams_router, prefix="/api/teams", tags=["teams"])
app.include_router(tournaments_router, prefix="/api/tournaments", tags=["tournaments"])
app.include_router(registrations_router, prefix="/api/registrations", tags=["registrations"])
app.include_router(ads_router, prefix="/api/ads", tags=["ads"])
app.include_router(admin_router, prefix="/api/admin", tags=["admin"])


@app.on_event("startup")
async def startup() -> None:
    logger.info("Starting application")
    if init_db():
        logger.info("Database ready")
    else:
        logger.error("Database initialization failed")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "arenahub-api"}
