-- MAC Learn: site-scoped operational administration
-- Site administrators manage operational records only when their classroom
-- belongs to their assigned site. Organization and Platform administrators
-- retain their existing broader policies.

create or replace function public.mac_is_site_classroom_admin(
  requested_organization_id uuid,
  requested_classroom_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classrooms classroom
    where classroom.id = requested_classroom_id
      and classroom.organization_id = requested_organization_id
      and classroom.site_id is not null
      and public.mac_is_site_admin(classroom.organization_id, classroom.site_id)
  );
$$;

revoke all on function public.mac_is_site_classroom_admin(uuid, uuid) from public;
grant execute on function public.mac_is_site_classroom_admin(uuid, uuid) to authenticated;

create policy "Site admins manage site classrooms"
on public.classrooms for all to authenticated
using (
  site_id is not null
  and public.mac_is_site_admin(organization_id, site_id)
)
with check (
  site_id is not null
  and public.mac_is_site_admin(organization_id, site_id)
);

create policy "Site admins manage site classroom educators"
on public.classroom_educators for all to authenticated
using (public.mac_is_site_classroom_admin(organization_id, classroom_id))
with check (public.mac_is_site_classroom_admin(organization_id, classroom_id));

create policy "Site admins manage site classroom enrollments"
on public.classroom_student_enrollments for all to authenticated
using (public.mac_is_site_classroom_admin(organization_id, classroom_id))
with check (public.mac_is_site_classroom_admin(organization_id, classroom_id));

create policy "Site admins manage site instructional records"
on public.educator_instructional_records for all to authenticated
using (public.mac_is_site_classroom_admin(organization_id, classroom_id))
with check (public.mac_is_site_classroom_admin(organization_id, classroom_id));
