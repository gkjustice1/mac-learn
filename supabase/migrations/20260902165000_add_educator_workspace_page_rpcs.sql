-- MAC Learn: relationship-scoped Educator workspace paging.
-- Keeps large-roster and large-classroom scopes bounded at the database boundary.

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
      and enrollment.enrolled_from <= current_date
      and (enrollment.enrolled_until is null or enrollment.enrolled_until >= current_date)
      and public.mac_is_active_classroom_educator(classroom.id)
  ),
  counted_students as (
    select student.id,
           student.first_name,
           student.last_name,
           student.grade_level,
           student.school_name,
           student.organization_id,
           student.primary_site_id,
           count(*) over () as total_count
    from eligible_students eligible
    join public.students student on student.id = eligible.student_id
    order by student.last_name, student.first_name, student.id
    offset greatest(p_offset, 0)
    limit least(greatest(p_limit, 1), 100)
  ),
  rendered_students as (
    select counted.id,
           counted.first_name,
           counted.last_name,
           counted.grade_level,
           counted.school_name,
           counted.organization_id,
           counted.primary_site_id,
           counted.total_count,
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
             where enrollment.student_id = counted.id
               and classroom.status = 'active'
               and enrollment.status = 'active'
               and enrollment.enrolled_from <= current_date
               and (enrollment.enrolled_until is null or enrollment.enrolled_until >= current_date)
               and public.mac_is_active_classroom_educator(classroom.id)
           ), '[]'::jsonb) as classrooms
    from counted_students counted
  )
  select jsonb_build_object(
    'total_count', coalesce(max(total_count), 0),
    'rows', coalesce(jsonb_agg(
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
    ), '[]'::jsonb)
  )
  from rendered_students;
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
           student.last_name as student_last_name,
           count(*) over () as total_count
    from public.educator_instructional_records record
    join public.classrooms classroom on classroom.id = record.classroom_id
    join public.students student on student.id = record.student_id
    where classroom.status = 'active'
      and public.mac_is_active_classroom_educator(classroom.id)
    order by record.occurred_on desc, record.id desc
    offset greatest(p_offset, 0)
    limit least(greatest(p_limit, 1), 100)
  )
  select jsonb_build_object(
    'total_count', coalesce(max(total_count), 0),
    'rows', coalesce(jsonb_agg(
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
    ), '[]'::jsonb)
  )
  from eligible_records;
$$;

revoke all on function public.mac_get_educator_student_page(integer, integer) from public, anon;
revoke all on function public.mac_get_educator_instructional_record_page(integer, integer) from public, anon;
grant execute on function public.mac_get_educator_student_page(integer, integer) to authenticated;
grant execute on function public.mac_get_educator_instructional_record_page(integer, integer) to authenticated;

comment on function public.mac_get_educator_student_page(integer, integer) is
  'Returns one bounded page of distinct students reachable only through the authenticated user active Educator classroom relationships, with visible classroom memberships and a total count.';
comment on function public.mac_get_educator_instructional_record_page(integer, integer) is
  'Returns one bounded page of instructional records reachable only through the authenticated user active Educator classroom relationships, with display names and a total count.';
