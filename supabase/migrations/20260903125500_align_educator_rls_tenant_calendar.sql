-- MAC Learn: align Educator student-access RLS with the tenant relationship calendar.
--
-- The Educator paging RPCs already evaluate enrollment lifecycle dates using
-- mac_relationship_calendar_date(...). Because those RPCs run as SECURITY
-- INVOKER, the underlying RLS helper must use the same calendar semantics or
-- RLS can incorrectly hide otherwise-current enrollments around UTC/local-day
-- boundaries.

create or replace function public.mac_educator_can_access_student(
  requested_classroom_id uuid,
  requested_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.mac_is_active_classroom_educator(requested_classroom_id)
    and exists (
      select 1
      from public.classroom_student_enrollments enrollment
      where enrollment.classroom_id = requested_classroom_id
        and enrollment.student_id = requested_student_id
        and enrollment.status = 'active'
        and enrollment.enrolled_from <= public.mac_relationship_calendar_date(
          enrollment.student_id,
          enrollment.organization_id
        )
        and (
          enrollment.enrolled_until is null
          or enrollment.enrolled_until >= public.mac_relationship_calendar_date(
            enrollment.student_id,
            enrollment.organization_id
          )
        )
    );
$$;

revoke all on function public.mac_educator_can_access_student(uuid, uuid) from public, anon;
grant execute on function public.mac_educator_can_access_student(uuid, uuid) to authenticated;

comment on function public.mac_educator_can_access_student(uuid, uuid) is
  'Returns true only when the authenticated Educator has an active classroom relationship and the student has a current active classroom enrollment evaluated using the student/organization tenant relationship calendar date.';
