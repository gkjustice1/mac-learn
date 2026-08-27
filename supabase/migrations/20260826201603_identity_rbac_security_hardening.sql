-- ============================================================
-- MAC Learn: Identity & RBAC security hardening
-- ============================================================

-- The legacy profile-role helper remains in use by baseline RLS
-- policies. Keep it available to signed-in policy evaluation, but
-- remove the default anonymous RPC execution surface and use a
-- safe, deterministic search path for its SECURITY DEFINER body.
create or replace function public.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select profile.role
  from public.profiles profile
  where profile.user_id = (select auth.uid());
$$;

revoke all on function public.current_user_role()
from public, anon;

grant execute on function public.current_user_role()
to authenticated;

-- Some existing environments include this event-trigger helper while
-- a clean local database does not. If present, it must never be callable
-- through the Data API by anon or authenticated users.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke all on function public.rls_auto_enable() from public, anon, authenticated;

    comment on function public.rls_auto_enable() is
      'Database event-trigger function that enables RLS for newly created public tables; not executable by API roles.';
  end if;
end;
$$;

comment on function public.current_user_role() is
  'Legacy profile-role helper retained for baseline RLS policies; executable by authenticated users only.';
