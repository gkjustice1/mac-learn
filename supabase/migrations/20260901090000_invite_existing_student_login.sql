-- Link a Supabase Auth invitation to an existing canonical student enrollment.

alter table public.student_enrollment_events
  drop constraint if exists student_enrollment_events_event_type_check;

alter table public.student_enrollment_events
  add constraint student_enrollment_events_event_type_check
  check (event_type in ('enrolled', 'updated', 'withdrawn', 'reactivated', 'login_invited'));

create or replace function public.mac_admin_validate_student_login_invitation(
  p_student_id uuid,
  p_email text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_student public.students%rowtype;
  v_email text;
  v_today date;
begin
  if auth.uid() is null or not public.mac_is_platform_admin() then
    raise exception 'not authorized to invite Student logins' using errcode = '42501';
  end if;

  v_email := lower(nullif(btrim(p_email), ''));
  if p_student_id is null or v_email is null then
    raise exception 'student and email are required' using errcode = '22023';
  end if;

  select * into v_student
  from public.students student
  where student.id = p_student_id;

  if not found
     or v_student.person_id is null
     or v_student.organization_id is null
     or v_student.primary_site_id is null
     or coalesce(v_student.enterprise_status, 'active') <> 'active' then
    raise exception 'active enrolled student with a canonical person and site was not found'
      using errcode = '22023';
  end if;

  v_today := public.mac_relationship_calendar_date(v_student.id, v_student.organization_id);
  if (v_student.enrollment_start_date is not null and v_student.enrollment_start_date > v_today)
     or (v_student.enrollment_end_date is not null and v_student.enrollment_end_date < v_today) then
    raise exception 'student enrollment is not current' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.organizations organization
    where organization.id = v_student.organization_id and organization.status = 'active'
  ) or not exists (
    select 1 from public.sites site
    where site.id = v_student.primary_site_id
      and site.organization_id = v_student.organization_id
      and site.status = 'active'
  ) then
    raise exception 'student organization or site is not active' using errcode = '22023';
  end if;

  if exists (select 1 from public.users app_user where app_user.person_id = v_student.person_id)
     or exists (select 1 from public.profiles profile where lower(profile.email) = v_email) then
    raise exception 'this student or email already has an application login' using errcode = '23505';
  end if;

  if exists (
    select 1 from public.people person
    where person.id = v_student.person_id
      and person.primary_email is not null
      and lower(person.primary_email) <> v_email
  ) then
    raise exception 'student person record has a different primary email' using errcode = '23505';
  end if;

  return v_student.id;
end;
$$;

revoke all on function public.mac_admin_validate_student_login_invitation(uuid, text) from public, anon;
grant execute on function public.mac_admin_validate_student_login_invitation(uuid, text) to authenticated;

create or replace function public.mac_admin_link_invited_student_login(
  p_user_id uuid,
  p_student_id uuid,
  p_email text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_student public.students%rowtype;
  v_auth_email text;
  v_guardian_id uuid;
  v_today date;
begin
  if auth.uid() is null or not public.mac_is_platform_admin() then
    raise exception 'not authorized to invite Student logins' using errcode = '42501';
  end if;

  if p_user_id is null or p_student_id is null or nullif(btrim(p_email), '') is null then
    raise exception 'student, user, and email are required' using errcode = '22023';
  end if;

  select * into v_student
  from public.students student
  where student.id = p_student_id
  for update;

  if not found
     or v_student.person_id is null
     or v_student.organization_id is null
     or v_student.primary_site_id is null
     or coalesce(v_student.enterprise_status, 'active') <> 'active' then
    raise exception 'active enrolled student with a canonical person and site was not found'
      using errcode = '22023';
  end if;

  v_today := public.mac_relationship_calendar_date(v_student.id, v_student.organization_id);
  if (v_student.enrollment_start_date is not null and v_student.enrollment_start_date > v_today)
     or (v_student.enrollment_end_date is not null and v_student.enrollment_end_date < v_today) then
    raise exception 'student enrollment is not current' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.organizations organization
    where organization.id = v_student.organization_id and organization.status = 'active'
  ) or not exists (
    select 1 from public.sites site
    where site.id = v_student.primary_site_id
      and site.organization_id = v_student.organization_id
      and site.status = 'active'
  ) then
    raise exception 'student organization or site is not active' using errcode = '22023';
  end if;

  select lower(auth_user.email) into v_auth_email
  from auth.users auth_user
  where auth_user.id = p_user_id;
  if not found or v_auth_email is distinct from lower(btrim(p_email)) then
    raise exception 'invited Auth identity does not match the requested email' using errcode = '22023';
  end if;

  if exists (select 1 from public.users app_user where app_user.person_id = v_student.person_id)
     or exists (select 1 from public.users app_user where app_user.id = p_user_id)
     or exists (select 1 from public.profiles profile where lower(profile.email) = v_auth_email) then
    raise exception 'this student or email already has an application login' using errcode = '23505';
  end if;

  update public.people
  set primary_email = v_auth_email
  where id = v_student.person_id
    and (primary_email is null or lower(primary_email) = v_auth_email);
  if not found then
    raise exception 'student person record has a different primary email' using errcode = '23505';
  end if;

  insert into public.users (id, person_id, account_status)
  values (p_user_id, v_student.person_id, 'invited');

  insert into public.profiles (
    user_id, full_name, email, role, organization_id, site_id, person_id, enterprise_user_id
  ) values (
    p_user_id,
    concat_ws(' ', v_student.first_name, v_student.last_name),
    v_auth_email,
    'student',
    v_student.organization_id,
    v_student.primary_site_id,
    v_student.person_id,
    p_user_id
  );

  perform set_config('mac.audit_reason', 'Existing student login invitation created.', true);
  insert into public.role_assignments (
    organization_id, user_id, site_id, role_key, status
  ) values (
    v_student.organization_id, p_user_id, v_student.primary_site_id, 'student', 'active'
  );

  select relationship.guardian_id into v_guardian_id
  from public.guardian_student_relationships relationship
  where relationship.student_id = v_student.id
    and relationship.organization_id = v_student.organization_id
  order by relationship.educational_access desc, relationship.created_at, relationship.id
  limit 1;

  insert into public.student_enrollment_events (
    student_id, organization_id, site_id, guardian_id, actor_user_id, event_type, details
  ) values (
    v_student.id,
    v_student.organization_id,
    v_student.primary_site_id,
    v_guardian_id,
    auth.uid(),
    'login_invited',
    jsonb_build_object('invited_user_id', p_user_id, 'email', v_auth_email)
  );

  return v_student.id;
end;
$$;

revoke all on function public.mac_admin_link_invited_student_login(uuid, uuid, text) from public, anon;
grant execute on function public.mac_admin_link_invited_student_login(uuid, uuid, text) to authenticated;
