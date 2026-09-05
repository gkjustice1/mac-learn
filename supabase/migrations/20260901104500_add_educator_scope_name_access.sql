-- MAC Learn: least-privilege Educator organization/site name access
--
-- Educator workspace scope labels must be available as soon as an authorized
-- Teacher or Academic Lead role becomes active, even before a classroom is
-- assigned. Scope visibility therefore follows the active role assignment that
-- authorizes /educator, while classroom/student/record access remains governed
-- by the existing relationship-based Educator policies.

create or replace function public.mac_is_active_educator_scope(
  requested_organization_id uuid,
  requested_site_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.role_assignments assignment
    join public.users enterprise_user on enterprise_user.id = assignment.user_id
    where assignment.user_id = auth.uid()
      and assignment.organization_id = requested_organization_id
      and assignment.role_key in ('teacher', 'academic_lead')
      and assignment.status = 'active'
      and assignment.valid_from <= now()
      and (assignment.valid_until is null or assignment.valid_until > now())
      and enterprise_user.account_status = 'active'
      and (
        requested_site_id is null
        or assignment.site_id is null
        or assignment.site_id = requested_site_id
      )
  );
$$;

revoke all on function public.mac_is_active_educator_scope(uuid, uuid) from public, anon;
grant execute on function public.mac_is_active_educator_scope(uuid, uuid) to authenticated;

drop policy if exists "Educators view assigned organizations" on public.organizations;
create policy "Educators view assigned organizations"
on public.organizations
for select
to authenticated
using (public.mac_is_active_educator_scope(id, null));

drop policy if exists "Educators view assigned sites" on public.sites;
create policy "Educators view assigned sites"
on public.sites
for select
to authenticated
using (public.mac_is_active_educator_scope(organization_id, id));

comment on function public.mac_is_active_educator_scope(uuid, uuid) is
  'Returns true only for the authenticated user active Teacher/Academic Lead organization/site role scope. Organization-wide assignments authorize site labels within that organization.';

comment on policy "Educators view assigned organizations" on public.organizations is
  'Educators may read only organizations covered by an active Teacher or Academic Lead role assignment.';

comment on policy "Educators view assigned sites" on public.sites is
  'Educators may read only sites covered by an active Teacher or Academic Lead role assignment; organization-wide assignments may read site labels within that organization.';
