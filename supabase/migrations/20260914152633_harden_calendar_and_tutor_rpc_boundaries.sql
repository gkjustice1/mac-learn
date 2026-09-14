-- Calendar metadata is organization-scoped. Return NULL for inaccessible or
-- nonexistent targets so RLS predicate evaluation fails closed without throwing.
-- Do not call student/family/educator visibility helpers here: they call these
-- calendar functions and would recurse. mac_can_access_organization is acyclic.
create or replace function public.mac_classroom_calendar_date(p_classroom_id uuid)
returns date
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select (now() at time zone coalesce(site.timezone, configuration.default_timezone, 'UTC'))::date
  from public.classrooms classroom
  left join public.sites site
    on site.id = classroom.site_id and site.organization_id = classroom.organization_id
  left join public.organization_configurations configuration
    on configuration.organization_id = classroom.organization_id
  where classroom.id = p_classroom_id
    and public.mac_can_access_organization(classroom.organization_id);
$$;

create or replace function public.mac_relationship_calendar_date(p_student_id uuid, p_organization_id uuid)
returns date
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select (now() at time zone coalesce(site.timezone, configuration.default_timezone, 'UTC'))::date
  from public.students student
  left join public.sites site
    on site.id = student.primary_site_id and site.organization_id = student.organization_id
  left join public.organization_configurations configuration
    on configuration.organization_id = student.organization_id
  where student.id = p_student_id
    and student.organization_id = p_organization_id
    and public.mac_can_access_organization(student.organization_id);
$$;

create or replace function public.mac_admin_update_tutor_profile(
  requested_tutor_id uuid,
  requested_approval_status approval_status default null,
  requested_hourly_rate numeric default null,
  requested_organization_id uuid default null,
  requested_site_id uuid default null,
  requested_person_id uuid default null,
  requested_staff_id uuid default null,
  requested_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $admin_update$
declare
  current_organization_id uuid;
  effective_organization_id uuid;
  effective_user_id uuid;
  replacement_profile_organization_id uuid;
begin
  -- Reject unauthorized callers before acquiring a row lock; recheck after it.
  if not public.mac_can_manage_tutor_profile(requested_tutor_id, requested_organization_id) then
    raise exception 'not authorized to manage tutor profile' using errcode = '42501';
  end if;

  select organization_id, user_id
  into current_organization_id, effective_user_id
  from public.tutor_profiles
  where id = requested_tutor_id
  for update;

  if not public.mac_can_manage_tutor_profile(
    requested_tutor_id,
    requested_organization_id
  ) then
    raise exception 'not authorized to manage tutor profile' using errcode = '42501';
  end if;

  effective_organization_id = coalesce(
    requested_organization_id,
    current_organization_id
  );

  effective_user_id = coalesce(requested_user_id, effective_user_id);

  if effective_user_id is not null then
    select organization_id into replacement_profile_organization_id
    from public.profiles
    where id = effective_user_id;

    if replacement_profile_organization_id is not null
       and replacement_profile_organization_id is distinct from effective_organization_id then
      raise exception 'replacement profile is outside the authorized organization' using errcode = '42501';
    end if;
  end if;

  update public.tutor_profiles
  set approval_status = coalesce(requested_approval_status, approval_status),
      hourly_rate = coalesce(requested_hourly_rate, hourly_rate),
      organization_id = coalesce(requested_organization_id, organization_id),
      site_id = coalesce(requested_site_id, site_id),
      person_id = coalesce(requested_person_id, person_id),
      staff_id = coalesce(requested_staff_id, staff_id),
      user_id = coalesce(requested_user_id, user_id)
  where id = requested_tutor_id;
end;
$admin_update$;

revoke all on function public.mac_admin_update_tutor_profile(uuid, approval_status, numeric, uuid, uuid, uuid, uuid, uuid) from public;
grant execute on function public.mac_admin_update_tutor_profile(uuid, approval_status, numeric, uuid, uuid, uuid, uuid, uuid) to authenticated;

create or replace function public.mac_admin_clear_tutor_profile_fields(
  requested_tutor_id uuid,
  clear_hourly_rate boolean default false,
  clear_site_id boolean default false,
  clear_person_id boolean default false,
  clear_staff_id boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $clear_tutor$
declare
  current_organization_id uuid;
begin
  -- Reject unauthorized callers before acquiring a row lock; recheck after it.
  if not public.mac_can_manage_tutor_profile(requested_tutor_id, null) then
    raise exception 'not authorized to manage tutor profile' using errcode = '42501';
  end if;

  select organization_id into current_organization_id
  from public.tutor_profiles
  where id = requested_tutor_id
  for update;

  if not public.mac_can_manage_tutor_profile(requested_tutor_id, null) then
    raise exception 'not authorized to manage tutor profile' using errcode = '42501';
  end if;

  update public.tutor_profiles
  set hourly_rate = case when clear_hourly_rate then null else hourly_rate end,
      site_id = case when clear_site_id then null else site_id end,
      person_id = case when clear_person_id then null else person_id end,
      staff_id = case when clear_staff_id then null else staff_id end
  where id = requested_tutor_id;
end;
$clear_tutor$;

revoke all on function public.mac_admin_clear_tutor_profile_fields(uuid, boolean, boolean, boolean, boolean) from public;
grant execute on function public.mac_admin_clear_tutor_profile_fields(uuid, boolean, boolean, boolean, boolean) to authenticated;

