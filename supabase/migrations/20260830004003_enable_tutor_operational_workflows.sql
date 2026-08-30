-- MAC Learn: operational Tutor workflows with tenant-safe administrator scheduling.

grant insert on table
  public.tutor_availability,
  public.session_notes,
  public.progress_reports
to authenticated;

revoke insert on table
  public.tutor_availability,
  public.session_notes,
  public.progress_reports
from anon;

alter table public.tutor_availability
  add constraint tutor_availability_valid_window
  check (end_time > start_time);

create or replace function public.mac_platform_admin_student_options()
returns table (
  id uuid,
  label text,
  organization_id uuid,
  site_id uuid
)
language sql
stable
security definer
set search_path = public
as $students$
  select
    student.id,
    concat(student.last_name, ', ', student.first_name, ' · Grade ', student.grade_level),
    student.organization_id,
    student.primary_site_id
  from public.students student
  where public.mac_is_platform_admin()
    and student.organization_id is not null
    and coalesce(student.enterprise_status, 'active') = 'active'
  order by student.last_name, student.first_name, student.id;
$students$;

revoke all on function public.mac_platform_admin_student_options() from public;
grant execute on function public.mac_platform_admin_student_options() to authenticated;

create or replace function public.mac_platform_admin_tutor_options()
returns table (
  id uuid,
  label text,
  organization_id uuid,
  site_id uuid
)
language sql
stable
security definer
set search_path = public
as $tutors$
  select distinct
    tutor.id,
    profile.full_name,
    tutor.organization_id,
    tutor.site_id
  from public.tutor_profiles tutor
  join public.profiles profile on profile.id = tutor.user_id
  join public.users enterprise_user on enterprise_user.id = profile.user_id
  join public.role_assignments assignment
    on assignment.user_id = enterprise_user.id
   and assignment.role_key = 'tutor'
   and assignment.status = 'active'
   and assignment.valid_from <= now()
   and (assignment.valid_until is null or assignment.valid_until > now())
   and assignment.organization_id = tutor.organization_id
   and (
     assignment.site_id is null
     or assignment.site_id = tutor.site_id
   )
  where public.mac_is_platform_admin()
    and enterprise_user.account_status = 'active'
    and tutor.organization_id is not null
  order by profile.full_name, tutor.id;
$tutors$;

revoke all on function public.mac_platform_admin_tutor_options() from public;
grant execute on function public.mac_platform_admin_tutor_options() to authenticated;

create or replace function public.mac_platform_admin_schedule_session(
  p_student_id uuid,
  p_tutor_id uuid,
  p_subject_id uuid,
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_zoom_link text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $schedule$
declare
  v_parent_id uuid;
  v_student_organization_id uuid;
  v_student_site_id uuid;
  v_tutor_organization_id uuid;
  v_tutor_site_id uuid;
  v_session_id uuid;
begin
  if auth.uid() is null or not public.mac_is_platform_admin() then
    raise exception 'not authorized to schedule Tutor sessions'
      using errcode = '42501';
  end if;

  if p_start_time is null or p_end_time is null or p_end_time <= p_start_time then
    raise exception 'session end time must be after its start time'
      using errcode = '22007';
  end if;

  select student.parent_id, student.organization_id, student.primary_site_id
  into v_parent_id, v_student_organization_id, v_student_site_id
  from public.students student
  where student.id = p_student_id
    and coalesce(student.enterprise_status, 'active') = 'active';

  if not found or v_student_organization_id is null then
    raise exception 'active enterprise student not found'
      using errcode = '22023';
  end if;

  select tutor.organization_id, tutor.site_id
  into v_tutor_organization_id, v_tutor_site_id
  from public.tutor_profiles tutor
  join public.profiles profile on profile.id = tutor.user_id
  join public.users enterprise_user on enterprise_user.id = profile.user_id
  where tutor.id = p_tutor_id
    and enterprise_user.account_status = 'active'
    and exists (
      select 1
      from public.role_assignments assignment
      where assignment.user_id = enterprise_user.id
        and assignment.role_key = 'tutor'
        and assignment.status = 'active'
        and assignment.valid_from <= now()
        and (assignment.valid_until is null or assignment.valid_until > now())
        and assignment.organization_id = tutor.organization_id
        and (
          assignment.site_id is null
          or assignment.site_id = tutor.site_id
        )
    );

  if not found or v_tutor_organization_id is null then
    raise exception 'active Tutor profile not found'
      using errcode = '22023';
  end if;

  if v_tutor_organization_id is distinct from v_student_organization_id then
    raise exception 'student and Tutor must belong to the same organization'
      using errcode = '42501';
  end if;

  if v_tutor_site_id is not null
     and v_tutor_site_id is distinct from v_student_site_id then
    raise exception 'student is outside the Tutor site scope'
      using errcode = '42501';
  end if;

  if p_subject_id is not null
     and not exists (select 1 from public.subjects where id = p_subject_id) then
    raise exception 'subject not found'
      using errcode = '22023';
  end if;

  insert into public.sessions (
    student_id,
    parent_id,
    tutor_id,
    subject_id,
    start_time,
    end_time,
    duration_minutes,
    status,
    zoom_link
  )
  values (
    p_student_id,
    v_parent_id,
    p_tutor_id,
    p_subject_id,
    p_start_time,
    p_end_time,
    greatest(1, ceil(extract(epoch from (p_end_time - p_start_time)) / 60)::int),
    'pending',
    nullif(btrim(p_zoom_link), '')
  )
  returning id into v_session_id;

  return v_session_id;
end;
$schedule$;

revoke all on function public.mac_platform_admin_schedule_session(
  uuid, uuid, uuid, timestamptz, timestamptz, text
) from public;
grant execute on function public.mac_platform_admin_schedule_session(
  uuid, uuid, uuid, timestamptz, timestamptz, text
) to authenticated;
