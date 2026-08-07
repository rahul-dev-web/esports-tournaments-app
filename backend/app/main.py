from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .auth.router import router as auth_router
from .users.router import router as users_router
from .teams.router import router as teams_router
from .tournaments.router import router as tournaments_router
from .registrations.router import router as registrations_router
from .admin.router import router as admin_router

app = FastAPI(title="ArenaHub Esports API", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
app.include_router(users_router, prefix="/api/users", tags=["users"])
app.include_router(teams_router, prefix="/api/teams", tags=["teams"])
app.include_router(tournaments_router, prefix="/api/tournaments", tags=["tournaments"])
app.include_router(registrations_router, prefix="/api/registrations", tags=["registrations"])
app.include_router(admin_router, prefix="/api/admin", tags=["admin"])

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "arenahub-api"}
