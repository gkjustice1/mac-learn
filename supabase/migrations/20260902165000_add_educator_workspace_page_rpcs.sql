-- MAC Learn: relationship-scoped Educator workspace paging.
-- Keeps classroom, roster, and instructional-record work bounded at the database boundary.

create or replace function public.mac_get_educator_classroom_page(
  p_offset integer default 0,
  p_limit integer default 100
)
returns jsonb
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  with eligible_classrooms as (
    select distinct classroom.id,
           classroom.organization_id,
           classroom.site_id,
           classroom.name,
           classroom.code,
           classroom.status
    from public.classroom_educators assignment
    join public.classrooms classroom on classroom.id = assignment.classroom_id
    where assignment.user_id = auth.uid()
      and assignment.status = 'active'
      and assignment.assigned_from <= current_date
      and (assignment.assigned_until is null or assignment.assigned_until >= current_date)
      and classroom.status = 'active'
      and public.mac_is_active_classroom_educator(classroom.id)
  ),
  totals as (
    select count(*)::bigint as total_count from eligible_classrooms
  ),
  paged as (
    select *
    from eligible_classrooms
    order by name, id
    offset greatest(p_offset, 0)
    limit least(greatest(p_limit, 1), 100)
  )
  select jsonb_build_object(
    'total_count', totals.total_count,
    'rows', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', id,
          'organization_id', organization_id,
          'site_id', site_id,
          'name', name,
          'code', code,
          'status', status
        ) order by name, id
      ) from paged
    ), '[]'::jsonb)
  )
  from totals;
$$;

create or replace function public.mac_get_educator_student_page(
  p_offset integer default 0,
  p_limit integer default 100
)
returns jsonb
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  with eligible_students as (
    select distinct enrollment.student_id
    from public.classroom_student_enrollments enrollment
    join public.classrooms classroom on classroom.id = enrollment.classroom_id
    where classroom.status = 'active'
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
      and public.mac_is_active_classroom_educator(classroom.id)
  ),
  totals as (
    select count(*)::bigint as total_count from eligible_students
  ),
  paged_students as (
    select student.id,
           student.first_name,
           student.last_name,
           student.grade_level,
           student.school_name,
           student.organization_id,
           student.primary_site_id
    from eligible_students eligible
    join public.students student on student.id = eligible.student_id
    order by student.last_name, student.first_name, student.id
    offset greatest(p_offset, 0)
    limit least(greatest(p_limit, 1), 100)
  ),
  rendered_students as (
    select paged.id,
           paged.first_name,
           paged.last_name,
           paged.grade_level,
           paged.school_name,
           paged.organization_id,
           paged.primary_site_id,
           coalesce((
             select jsonb_agg(
               jsonb_build_object(
                 'classroom_id', classroom.id,
                 'classroom_name', classroom.name,
                 'organization_id', classroom.organization_id,
                 'site_id', classroom.site_id
               ) order by classroom.name, classroom.id
             )
             from public.classroom_student_enrollments enrollment
             join public.classrooms classroom on classroom.id = enrollment.classroom_id
             where enrollment.student_id = paged.id
               and classroom.status = 'active'
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
               and public.mac_is_active_classroom_educator(classroom.id)
           ), '[]'::jsonb) as classrooms
    from paged_students paged
  )
  select jsonb_build_object(
    'total_count', totals.total_count,
    'rows', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', id,
          'first_name', first_name,
          'last_name', last_name,
          'grade_level', grade_level,
          'school_name', school_name,
          'organization_id', organization_id,
          'primary_site_id', primary_site_id,
          'classrooms', classrooms
        ) order by last_name, first_name, id
      ) from rendered_students
    ), '[]'::jsonb)
  )
  from totals;
$$;

create or replace function public.mac_get_educator_instructional_record_page(
  p_offset integer default 0,
  p_limit integer default 100
)
returns jsonb
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  with eligible_records as (
    select record.id,
           record.organization_id,
           record.classroom_id,
           record.student_id,
           record.record_type,
           record.content,
           record.occurred_on,
           classroom.site_id,
           classroom.name as classroom_name,
           student.first_name as student_first_name,
           student.last_name as student_last_name
    from public.educator_instructional_records record
    join public.classrooms classroom on classroom.id = record.classroom_id
    join public.students student on student.id = record.student_id
    where classroom.status = 'active'
      and public.mac_is_active_classroom_educator(classroom.id)
      and exists (
        select 1
        from public.classroom_student_enrollments enrollment
        where enrollment.organization_id = record.organization_id
          and enrollment.classroom_id = record.classroom_id
          and enrollment.student_id = record.student_id
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
      )
  ),
  totals as (
    select count(*)::bigint as total_count from eligible_records
  ),
  paged as (
    select * from eligible_records
    order by occurred_on desc, id desc
    offset greatest(p_offset, 0)
    limit least(greatest(p_limit, 1), 100)
  )
  select jsonb_build_object(
    'total_count', totals.total_count,
    'rows', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', id,
          'organization_id', organization_id,
          'classroom_id', classroom_id,
          'student_id', student_id,
          'record_type', record_type,
          'content', content,
          'occurred_on', occurred_on,
          'site_id', site_id,
          'classroom_name', classroom_name,
          'student_first_name', student_first_name,
          'student_last_name', student_last_name
        ) order by occurred_on desc, id desc
      ) from paged
    ), '[]'::jsonb)
  )
  from totals;
$$;

revoke all on function public.mac_get_educator_classroom_page(integer, integer) from public, anon;
revoke all on function public.mac_get_educator_student_page(integer, integer) from public, anon;
revoke all on function public.mac_get_educator_instructional_record_page(integer, integer) from public, anon;
grant execute on function public.mac_get_educator_classroom_page(integer, integer) to authenticated;
grant execute on function public.mac_get_educator_student_page(integer, integer) to authenticated;
grant execute on function public.mac_get_educator_instructional_record_page(integer, integer) to authenticated;

comment on function public.mac_get_educator_classroom_page(integer, integer) is
  'Returns one bounded page of active classrooms assigned to the authenticated Educator plus an exact total count.';
comment on function public.mac_get_educator_student_page(integer, integer) is
  'Returns one bounded page of distinct students reachable only through active Educator classroom relationships, with visible classroom memberships and an exact total count using each student tenant calendar date.';
comment on function public.mac_get_educator_instructional_record_page(integer, integer) is
  'Returns one bounded page of instructional records reachable only through active Educator classroom relationships and current classroom enrollment, with display names and an exact total count.';
