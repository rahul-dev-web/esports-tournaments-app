# ArenaHub Esports Tournaments

Scalable Flutter + FastAPI + Supabase starter for esports tournaments, teams, rewarded-ad registration, notifications, and admin operations.

## Current foundation

- FastAPI modules for auth/profile, teams, tournaments, registrations, and admin dashboard
- Configurable `individual_ads` or `captain_ads` registration policy
- Server-side ad verification state machine and tournament slot assignment
- Supabase PostgreSQL schema with RLS, notifications, settings, and audit logs
- Flutter Riverpod starter screens and a Next.js admin starter

See [`docs/architecture.md`](docs/architecture.md) for setup and production hardening steps.

## Run locally

### Backend API

From `backend`:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
$env:DATABASE_URL = "sqlite:///./arenahub.db"
python init_db.py
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Open the API docs at <http://127.0.0.1:8000/docs> and verify <http://127.0.0.1:8000/health>.
For PostgreSQL/Supabase, replace `DATABASE_URL` with the connection string before running `init_db.py`.

### Admin panel

From `admin-panel`:

```powershell
npm install
npm run dev
```

Open <http://localhost:3000>.

### Flutter mobile app

From `mobile`, with an emulator or device available:

```powershell
flutter pub get
flutter run
```

The mobile app is currently a UI starter; its sign-in and tournament actions are not yet connected to the API.
