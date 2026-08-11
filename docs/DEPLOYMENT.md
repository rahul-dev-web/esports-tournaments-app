# Deployment

Backend:

- Deploy FastAPI with production `DATABASE_URL` pointing at Supabase PostgreSQL.
- Set `CORS_ORIGINS` to the actual admin/mobile web origins.
- Configure Firebase and AdMob environment variables server-side only.

Admin panel:

- Set `NEXT_PUBLIC_API_BASE_URL` per environment.
- Build verified successfully with `npm run build`.

Mobile:

- Provide build-time `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `OAUTH_REDIRECT_URL`.
- iOS deployment still requires macOS/Xcode.

AdMob:

- Configure the public SSV callback URL only after the backend is publicly reachable.

