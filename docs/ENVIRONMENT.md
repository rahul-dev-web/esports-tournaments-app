# Environment

Backend env:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_JWT_SECRET`
- `DATABASE_URL`
- `ENVIRONMENT`
- `DEBUG`
- `BACKEND_HOST`
- `BACKEND_PORT`
- `CORS_ORIGINS`
- `ADMIN_EMAILS`
- Firebase vars
- AdMob vars

Admin env:

- `NEXT_PUBLIC_API_BASE_URL`

Mobile env:

- `API_BASE_URL`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `OAUTH_REDIRECT_URL`

Rules:

- Never commit secrets.
- Production values must be environment-driven, not hard-coded.
