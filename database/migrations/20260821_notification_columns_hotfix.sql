-- Hotfix: keep the production notifications table aligned with the SQLAlchemy model.
-- The backend inserts notification_type and data when publishing tournaments.
-- This migration is idempotent and safe to run against existing databases.

begin;

alter table public.notifications
  add column if not exists notification_type text not null default 'general';

alter table public.notifications
  add column if not exists data jsonb not null default '{}'::jsonb;

create index if not exists idx_notifications_type
  on public.notifications(notification_type);

commit;
