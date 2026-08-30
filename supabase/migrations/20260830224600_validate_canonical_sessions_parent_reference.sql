-- Validate the nullable legacy parent reference in a separate transaction so
-- the preceding constraint replacement's ACCESS EXCLUSIVE lock is released
-- before PostgreSQL scans existing session history.

alter table public.sessions
  validate constraint sessions_parent_id_fkey;
