# Setup

Current status:

- Backend: FastAPI + SQLAlchemy, configured for Supabase PostgreSQL in production and SQLite only for local dev.
- Mobile: Flutter app uses Supabase session tokens and configurable API/Supabase env defines.
- Admin panel: Next.js build verified after config fixes.

Local backend:

1. Copy `backend/.env.example` to `backend/.env.local`.
2. Fill Supabase, Firebase, and AdMob variables.
3. Run the backend from `backend/` so `app.*` imports resolve.

Local admin panel:

1. Copy `admin-panel/.env.example` to `admin-panel/.env.local`.
2. Set `NEXT_PUBLIC_API_BASE_URL`.
3. Run `npm run dev` or `npm run build` from `admin-panel/`.

Local mobile:

1. Pass `API_BASE_URL`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY` at build time.
2. Configure deep links for `com.arenahub.arenahub_mobile://login-callback/`.

