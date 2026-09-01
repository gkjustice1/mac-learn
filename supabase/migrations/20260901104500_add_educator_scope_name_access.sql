-- MAC Learn: least-privilege Educator organization/site name access
--
-- Educator workspace headers need the names of only the organization and site
-- that contain an actively assigned classroom. Existing classroom authorization
-- remains the source of truth; these policies do not broaden classroom access.

drop policy if exists "Educators view assigned organizations" on public.organizations;
create policy "Educators view assigned organizations"
on public.organizations
for select
to authenticated
using (
  exists (
    select 1
    from public.classrooms classroom
    where classroom.organization_id = organizations.id
      and public.mac_is_active_classroom_educator(classroom.id)
  )
);

drop policy if exists "Educators view assigned sites" on public.sites;
create policy "Educators view assigned sites"
on public.sites
for select
to authenticated
using (
  exists (
    select 1
    from public.classrooms classroom
    where classroom.organization_id = sites.organization_id
      and classroom.site_id = sites.id
      and public.mac_is_active_classroom_educator(classroom.id)
  )
);

comment on policy "Educators view assigned organizations" on public.organizations is
  'Educators may read an organization row only when they have an active authorized classroom assignment in that organization.';

comment on policy "Educators view assigned sites" on public.sites is
  'Educators may read a site row only when they have an active authorized classroom assignment at that exact organization/site.';
