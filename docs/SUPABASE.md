# Supabase

Configured externally:

- Google provider enabled.
- Mobile redirect URL: `com.arenahub.arenahub_mobile://login-callback/`.
- Buckets already exist: `profile-photos`, `team-logos`.

Database contract:

- Authoritative SQL: `database/schema.sql`.
- Tables include profiles, teams, team_members, team_invitations, tournaments, tournament_registrations, reward_ad_events, notifications, device_tokens, settings, and audit_logs.
- RLS policies and storage policies are included in the SQL file.

Storage path convention:

- Profile photos: `{user_id}/avatar.*`
- Team logos: `{team_id}/logo.*`

