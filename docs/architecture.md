# ArenaHub architecture

The repository is a feature-first monorepo:

- `backend/`: FastAPI API boundary. The current starter keeps a memory store for local development; production wiring should replace it with Supabase repositories and verify Supabase JWTs.
- `database/`: Supabase PostgreSQL schema, RLS starting policies, and audit tables.
- `mobile/`: Flutter + Riverpod starter. Add generated platform folders with `flutter create mobile` when Flutter SDK is available.
- `admin-panel/`: lightweight Next.js starter for admin dashboard integration.

Registration is a server-owned state machine. A captain starts a registration, the API records verified ad events, and the configured policy determines whether the required count comes from team members or the captain. Slot assignment occurs only on the transition to `registered`.

## Run API

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The local auth boundary accepts `X-User-Id`. Replace it with Supabase access-token verification before shipping.
