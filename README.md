# ArenaHub Esports Tournaments

Scalable Flutter + FastAPI + Supabase starter for esports tournaments, teams, rewarded-ad registration, notifications, and admin operations.

## Current foundation

- FastAPI modules for auth/profile, teams, tournaments, registrations, and admin dashboard
- Configurable `individual_ads` or `captain_ads` registration policy
- Server-side ad verification state machine and tournament slot assignment
- Supabase PostgreSQL schema with RLS, notifications, settings, and audit logs
- Flutter Riverpod starter screens and a Next.js admin starter

See [`docs/architecture.md`](docs/architecture.md) for setup and production hardening steps.
