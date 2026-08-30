-- Profiles participate in authenticated workspace and RLS policy lookups.
-- The existing SELECT policy limits each caller to the row linked to auth.uid().

grant select on table public.profiles to authenticated;
revoke select on table public.profiles from anon;
