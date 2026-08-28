-- MAC Learn: site-scoped operational administration
-- Site administrators manage operational records only when their classroom
-- belongs to their assigned site. Organization and Platform administrators
-- retain their existing broader policies.

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
using (exists (
  select 1 from public.classrooms classroom
  where classroom.id = classroom_educators.classroom_id
    and classroom.organization_id = classroom_educators.organization_id
    and classroom.site_id is not null
    and public.mac_is_site_admin(classroom.organization_id, classroom.site_id)
))
with check (exists (
  select 1 from public.classrooms classroom
  where classroom.id = classroom_educators.classroom_id
    and classroom.organization_id = classroom_educators.organization_id
    and classroom.site_id is not null
    and public.mac_is_site_admin(classroom.organization_id, classroom.site_id)
));

create policy "Site admins manage site classroom enrollments"
on public.classroom_student_enrollments for all to authenticated
using (exists (
  select 1 from public.classrooms classroom
  where classroom.id = classroom_student_enrollments.classroom_id
    and classroom.organization_id = classroom_student_enrollments.organization_id
    and classroom.site_id is not null
    and public.mac_is_site_admin(classroom.organization_id, classroom.site_id)
))
with check (exists (
  select 1 from public.classrooms classroom
  where classroom.id = classroom_student_enrollments.classroom_id
    and classroom.organization_id = classroom_student_enrollments.organization_id
    and classroom.site_id is not null
    and public.mac_is_site_admin(classroom.organization_id, classroom.site_id)
));

create policy "Site admins manage site instructional records"
on public.educator_instructional_records for all to authenticated
using (exists (
  select 1 from public.classrooms classroom
  where classroom.id = educator_instructional_records.classroom_id
    and classroom.organization_id = educator_instructional_records.organization_id
    and classroom.site_id is not null
    and public.mac_is_site_admin(classroom.organization_id, classroom.site_id)
))
with check (exists (
  select 1 from public.classrooms classroom
  where classroom.id = educator_instructional_records.classroom_id
    and classroom.organization_id = educator_instructional_records.organization_id
    and classroom.site_id is not null
    and public.mac_is_site_admin(classroom.organization_id, classroom.site_id)
));
