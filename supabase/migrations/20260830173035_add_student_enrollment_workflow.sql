-- MAC Learn: secure administrator student enrollment.

alter table public.students
  drop constraint if exists students_enterprise_status_check;

alter table public.students
  add constraint students_enterprise_status_check
  check (enterprise_status in ('active', 'inactive', 'withdrawn', 'archived'))
  not valid;

create table public.student_enrollment_events (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  site_id uuid references public.sites(id) on delete set null,
  guardian_id uuid not null references public.guardians(id) on delete restrict,
  actor_user_id uuid references public.users(id) on delete set null,
  event_type text not null check (event_type in ('enrolled', 'updated', 'withdrawn', 'reactivated')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index student_enrollment_events_student_created_idx
  on public.student_enrollment_events(student_id, created_at desc);

create index student_enrollment_events_organization_created_idx
  on public.student_enrollment_events(organization_id, created_at desc);

alter table public.student_enrollment_events enable row level security;

create policy "Enterprise admins view enrollment events"
on public.student_enrollment_events
for select
to authenticated
using (public.mac_is_organization_admin(organization_id));

revoke all on table public.student_enrollment_events from public, anon;
revoke insert, update, delete on table public.student_enrollment_events from authenticated;
grant select on table public.student_enrollment_events to authenticated;

create or replace function public.mac_admin_enroll_student(
  p_first_name text,
  p_last_name text,
  p_grade_level text,
  p_school_name text,
  p_organization_id uuid,
  p_site_id uuid,
  p_enrollment_start_date date,
  p_enterprise_status text,
  p_guardian_user_id uuid,
  p_relationship_type text default 'parent_guardian'
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_student_person_id uuid;
  v_student_id uuid;
  v_guardian_person_id uuid;
  v_guardian_profile_id uuid;
  v_guardian_id uuid;
begin
  if auth.uid() is null or not public.mac_is_organization_admin(p_organization_id) then
    raise exception 'Not authorized to enroll students in this organization';
  end if;

  if nullif(btrim(p_first_name), '') is null
     or nullif(btrim(p_last_name), '') is null
     or nullif(btrim(p_grade_level), '') is null then
    raise exception 'Student first name, last name, and grade level are required';
  end if;

  if p_enterprise_status is null or p_enterprise_status not in ('active', 'inactive') then
    raise exception 'New enrollment status must be active or inactive';
  end if;

  if p_relationship_type is null
     or p_relationship_type not in ('parent_guardian', 'parent', 'guardian', 'caregiver') then
    raise exception 'Guardian relationship type is invalid';
  end if;

  if p_enrollment_start_date is null then
    raise exception 'Enrollment start date is required';
  end if;

  if not exists (
    select 1
    from public.organizations organization
    where organization.id = p_organization_id
      and organization.status = 'active'
  ) then
    raise exception 'The selected organization is not active';
  end if;

  if not exists (
    select 1
    from public.sites site
    where site.id = p_site_id
      and site.organization_id = p_organization_id
      and site.status = 'active'
  ) then
    raise exception 'The selected site is not active in this organization';
  end if;

  select enterprise_user.person_id, profile.id
  into v_guardian_person_id, v_guardian_profile_id
  from public.users enterprise_user
  join public.profiles profile
    on profile.user_id = enterprise_user.id
   and profile.person_id = enterprise_user.person_id
   and profile.organization_id = p_organization_id
  where enterprise_user.id = p_guardian_user_id
    and enterprise_user.account_status in ('invited', 'active')
    and exists (
      select 1
      from public.role_assignments assignment
      where assignment.user_id = enterprise_user.id
        and assignment.organization_id = p_organization_id
        and assignment.role_key = 'guardian'
        and assignment.status = 'active'
        and assignment.valid_from <= now()
        and (assignment.valid_until is null or assignment.valid_until > now())
        and (assignment.site_id is null or assignment.site_id = p_site_id)
    )
  for update of enterprise_user;

  if v_guardian_person_id is null or v_guardian_profile_id is null then
    raise exception 'The selected guardian is not invited or active in this organization and site';
  end if;

  insert into public.guardians (organization_id, person_id, status)
  values (p_organization_id, v_guardian_person_id, 'active')
  on conflict (organization_id, person_id)
  do update set status = 'active', updated_at = now()
  returning id into v_guardian_id;

  insert into public.people (first_name, last_name)
  values (btrim(p_first_name), btrim(p_last_name))
  returning id into v_student_person_id;

  insert into public.students (
    parent_id,
    first_name,
    last_name,
    grade_level,
    school_name,
    organization_id,
    person_id,
    primary_site_id,
    enterprise_status,
    enrollment_start_date
  )
  values (
    v_guardian_profile_id,
    btrim(p_first_name),
    btrim(p_last_name),
    btrim(p_grade_level),
    nullif(btrim(p_school_name), ''),
    p_organization_id,
    v_student_person_id,
    p_site_id,
    p_enterprise_status,
    p_enrollment_start_date
  )
  returning id into v_student_id;

  insert into public.guardian_student_relationships (
    organization_id,
    guardian_id,
    student_id,
    relationship_type,
    educational_access,
    emergency_contact,
    contact_priority,
    valid_from
  )
  values (
    p_organization_id,
    v_guardian_id,
    v_student_id,
    coalesce(nullif(btrim(p_relationship_type), ''), 'parent_guardian'),
    true,
    true,
    1,
    p_enrollment_start_date
  );

  insert into public.student_enrollment_events (
    student_id,
    organization_id,
    site_id,
    guardian_id,
    actor_user_id,
    event_type,
    details
  )
  values (
    v_student_id,
    p_organization_id,
    p_site_id,
    v_guardian_id,
    auth.uid(),
    'enrolled',
    jsonb_build_object(
      'grade_level', btrim(p_grade_level),
      'school_name', nullif(btrim(p_school_name), ''),
      'enterprise_status', p_enterprise_status,
      'enrollment_start_date', p_enrollment_start_date,
      'relationship_type', coalesce(nullif(btrim(p_relationship_type), ''), 'parent_guardian')
    )
  );

  return v_student_id;
end;
$$;

comment on function public.mac_admin_enroll_student(text, text, text, text, uuid, uuid, date, text, uuid, text) is
  'Transactionally enrolls a student and links an invited or active guardian after organization and site authorization checks.';

revoke all on function public.mac_admin_enroll_student(text, text, text, text, uuid, uuid, date, text, uuid, text)
from public, anon;
grant execute on function public.mac_admin_enroll_student(text, text, text, text, uuid, uuid, date, text, uuid, text)
to authenticated;
