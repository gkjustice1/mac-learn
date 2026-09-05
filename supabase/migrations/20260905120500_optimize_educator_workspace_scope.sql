-- MAC Learn: optimize Educator workspace paging by seeding all Student and
-- instructional-record access from the authenticated Educator's active classroom
-- relationships before joining shared tenant tables.

create index if not exists idx_classroom_student_enrollments_org_classroom_status_student
  on public.classroom_student_enrollments (organization_id, classroom_id, status, student_id);

create index if not exists idx_educator_instructional_records_org_classroom_occurred_id
  on public.educator_instructional_records (organization_id, classroom_id, occurred_on desc, id desc);

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
  with assigned_classrooms as (
    select distinct classroom.id as classroom_id,
           classroom.organization_id,
           classroom.site_id,
           classroom.name as classroom_name
    from public.classroom_educators assignment
    join public.classrooms classroom on classroom.id = assignment.classroom_id
    where assignment.user_id = auth.uid()
      and assignment.status = 'active'
      and assignment.assigned_from <= public.mac_classroom_calendar_date(classroom.id)
      and (
        assignment.assigned_until is null
        or assignment.assigned_until >= public.mac_classroom_calendar_date(classroom.id)
      )
      and classroom.status = 'active'
      and public.mac_is_active_classroom_educator(classroom.id)
  ),
  eligible_students as (
    select distinct student.id as student_id
    from assigned_classrooms assigned
    join public.classroom_student_enrollments enrollment
      on enrollment.organization_id = assigned.organization_id
     and enrollment.classroom_id = assigned.classroom_id
    join public.students student
      on student.id = enrollment.student_id
     and student.organization_id = enrollment.organization_id
    where student.enterprise_status = 'active'
      and (
        student.enrollment_start_date is null
        or student.enrollment_start_date <= public.mac_relationship_calendar_date(
          student.id,
          student.organization_id
        )
      )
      and (
        student.enrollment_end_date is null
        or student.enrollment_end_date >= public.mac_relationship_calendar_date(
          student.id,
          student.organization_id
        )
      )
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
                 'classroom_id', assigned.classroom_id,
                 'classroom_name', assigned.classroom_name,
                 'organization_id', assigned.organization_id,
                 'site_id', assigned.site_id
               ) order by assigned.classroom_name, assigned.classroom_id
             )
             from assigned_classrooms assigned
             join public.classroom_student_enrollments enrollment
               on enrollment.organization_id = assigned.organization_id
              and enrollment.classroom_id = assigned.classroom_id
             where enrollment.student_id = paged.id
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
  with assigned_classrooms as (
    select distinct classroom.id as classroom_id,
           classroom.organization_id,
           classroom.site_id,
           classroom.name as classroom_name
    from public.classroom_educators assignment
    join public.classrooms classroom on classroom.id = assignment.classroom_id
    where assignment.user_id = auth.uid()
      and assignment.status = 'active'
      and assignment.assigned_from <= public.mac_classroom_calendar_date(classroom.id)
      and (
        assignment.assigned_until is null
        or assignment.assigned_until >= public.mac_classroom_calendar_date(classroom.id)
      )
      and classroom.status = 'active'
      and public.mac_is_active_classroom_educator(classroom.id)
  ),
  eligible_records as (
    select record.id,
           record.organization_id,
           record.classroom_id,
           record.student_id,
           record.record_type,
           record.content,
           record.occurred_on,
           assigned.site_id,
           assigned.classroom_name,
           student.first_name as student_first_name,
           student.last_name as student_last_name
    from assigned_classrooms assigned
    join public.educator_instructional_records record
      on record.organization_id = assigned.organization_id
     and record.classroom_id = assigned.classroom_id
    join public.students student
      on student.id = record.student_id
     and student.organization_id = record.organization_id
    where student.enterprise_status = 'active'
      and (
        student.enrollment_start_date is null
        or student.enrollment_start_date <= public.mac_relationship_calendar_date(
          student.id,
          student.organization_id
        )
      )
      and (
        student.enrollment_end_date is null
        or student.enrollment_end_date >= public.mac_relationship_calendar_date(
          student.id,
          student.organization_id
        )
      )
      and exists (
        select 1
        from public.classroom_student_enrollments enrollment
        where enrollment.organization_id = assigned.organization_id
          and enrollment.classroom_id = assigned.classroom_id
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

revoke all on function public.mac_get_educator_student_page(integer, integer) from public, anon;
revoke all on function public.mac_get_educator_instructional_record_page(integer, integer) from public, anon;
grant execute on function public.mac_get_educator_student_page(integer, integer) to authenticated;
grant execute on function public.mac_get_educator_instructional_record_page(integer, integer) to authenticated;

comment on function public.mac_get_educator_student_page(integer, integer) is
  'Returns one bounded Student page seeded from the authenticated Educator active classroom relationships before joining shared enrollment data.';
comment on function public.mac_get_educator_instructional_record_page(integer, integer) is
  'Returns one bounded instructional-record page seeded from the authenticated Educator active classroom relationships and supported by an organization/classroom-leading record index.';
