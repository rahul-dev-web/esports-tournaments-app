-- Notification metadata required by backend + mobile deep-link handling.
-- Apply this migration to the Supabase/PostgreSQL database before deploying
-- the notification metadata changes.

begin;

alter table public.notifications
  add column if not exists notification_type text not null default 'general';

alter table public.notifications
  add column if not exists data jsonb not null default '{}'::jsonb;

create index if not exists idx_notifications_type
  on public.notifications(notification_type);

commit;
