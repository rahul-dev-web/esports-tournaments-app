# Architecture

Source of truth:

- Production database: Supabase PostgreSQL.
- Production auth: Supabase Auth.
- File storage: Supabase Storage.

Backend:

- FastAPI exposes `/api/auth`, `/api/users`, `/api/teams`, `/api/tournaments`, `/api/registrations`, `/api/ads`, `/api/notifications`, `/api/admin`.
- JWT verification happens in `backend/app/common/deps.py`.
- Registration and SSV handling are server-side and transaction-aware.

Client:

- Flutter uses Supabase session tokens.
- Admin panel uses a configurable backend base URL.
