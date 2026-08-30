-- MAC Learn: secure administrator student enrollment.

alter table public.students
  drop constraint if exists students_enterprise_status_check;

alter table public.students
  add constraint students_enterprise_status_check
  check (enterprise_status in ('active', 'inactive', 'withdrawn', 'archived'))
  not valid;

alter table public.students
  alter column parent_id drop not null;

alter table public.students
  drop constraint if exists students_parent_id_fkey;

alter table public.students
  add constraint students_parent_id_fkey
  foreign key (parent_id) references public.profiles(id) on delete set null;

create table public.student_enrollment_events (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  site_id uuid references public.sites(id) on delete set null,
  guardian_id uuid references public.guardians(id) on delete restrict,
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

create or replace function public.mac_audit_student_enrollment_status()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_guardian_id uuid;
  v_event_type text;
begin
  if new.enterprise_status is not distinct from old.enterprise_status then
    return new;
  end if;

  if new.organization_id is null then
    raise exception 'Student status changes require an organization for audit history';
  end if;

  select relationship.guardian_id
  into v_guardian_id
  from public.guardian_student_relationships relationship
  where relationship.student_id = new.id
    and relationship.organization_id = new.organization_id
  order by relationship.educational_access desc, relationship.created_at, relationship.id
  limit 1;

  v_event_type := case
    when new.enterprise_status = 'withdrawn' then 'withdrawn'
    when new.enterprise_status = 'active' and old.enterprise_status is distinct from 'active' then 'reactivated'
    else 'updated'
  end;

  insert into public.student_enrollment_events (
    student_id,
    organization_id,
    site_id,
    guardian_id,
    actor_user_id,
    event_type,
    details
  ) values (
    new.id,
    new.organization_id,
    new.primary_site_id,
    v_guardian_id,
    auth.uid(),
    v_event_type,
    jsonb_build_object(
      'previous_enterprise_status', old.enterprise_status,
      'enterprise_status', new.enterprise_status
    )
  );

  return new;
end;
$$;

revoke all on function public.mac_audit_student_enrollment_status() from public, anon, authenticated;

drop trigger if exists audit_student_enrollment_status on public.students;
create trigger audit_student_enrollment_status
after update of enterprise_status on public.students
for each row
execute function public.mac_audit_student_enrollment_status();

create or replace function public.mac_relationship_calendar_date(
  p_student_id uuid,
  p_organization_id uuid
)
returns date
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (
      select (now() at time zone site.timezone)::date
      from public.students student
      join public.sites site
        on site.id = student.primary_site_id
       and site.organization_id = student.organization_id
      where student.id = p_student_id
        and student.organization_id = p_organization_id
    ),
    current_date
  );
$$;

revoke all on function public.mac_relationship_calendar_date(uuid, uuid) from public, anon;
grant execute on function public.mac_relationship_calendar_date(uuid, uuid) to authenticated;

create or replace function public.mac_admin_search_guardians(
  p_organization_id uuid,
  p_site_id uuid,
  p_query text
)
returns table (user_id uuid, label text)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select distinct
    enterprise_user.id,
    concat(
      person.first_name, ' ', person.last_name, ' — ',
      coalesce(person.primary_email, enterprise_user.id::text),
      ' (', enterprise_user.account_status, ')'
    )
  from public.people person
  join public.users enterprise_user on enterprise_user.person_id = person.id
  join public.profiles profile
    on profile.user_id = enterprise_user.id
   and profile.person_id = person.id
   and profile.organization_id = p_organization_id
  join public.role_assignments assignment
    on assignment.user_id = enterprise_user.id
   and assignment.organization_id = p_organization_id
   and assignment.role_key = 'guardian'
   and assignment.status = 'active'
   and assignment.valid_from <= now()
   and (assignment.valid_until is null or assignment.valid_until > now())
   and (assignment.site_id is null or assignment.site_id = p_site_id)
  where public.mac_is_platform_admin()
    and enterprise_user.account_status in ('active', 'invited')
    and length(btrim(p_query)) >= 2
    and exists (
      select 1
      from public.sites site
      where site.id = p_site_id
        and site.organization_id = p_organization_id
        and site.status = 'active'
    )
    and position(
      lower(btrim(p_query)) in lower(concat_ws(' ', person.first_name, person.last_name, person.primary_email))
    ) > 0
    and not exists (
      select 1
      from public.guardians guardian
      where guardian.organization_id = p_organization_id
        and guardian.person_id = person.id
        and guardian.status <> 'active'
    )
  order by 2
  limit 20;
$$;

revoke all on function public.mac_admin_search_guardians(uuid, uuid, text) from public, anon;
grant execute on function public.mac_admin_search_guardians(uuid, uuid, text) to authenticated;

drop policy if exists "Authenticated guardians view active educational relationships"
on public.guardian_student_relationships;

create policy "Authenticated guardians view active educational relationships"
on public.guardian_student_relationships
for select
to authenticated
using (public.mac_is_organization_admin(organization_id) or exists (
  select 1
  from public.guardians guardian
  join public.users enterprise_user on enterprise_user.person_id = guardian.person_id
  where guardian.id = guardian_student_relationships.guardian_id
    and guardian.organization_id = guardian_student_relationships.organization_id
    and guardian.status = 'active'
    and enterprise_user.id = (select auth.uid())
    and enterprise_user.account_status = 'active'
    and guardian_student_relationships.educational_access
    and (
      guardian_student_relationships.valid_from is null
      or guardian_student_relationships.valid_from <= public.mac_relationship_calendar_date(
        guardian_student_relationships.student_id,
        guardian_student_relationships.organization_id
      )
    )
    and (
      guardian_student_relationships.valid_until is null
      or guardian_student_relationships.valid_until >= public.mac_relationship_calendar_date(
        guardian_student_relationships.student_id,
        guardian_student_relationships.organization_id
      )
    )
));

drop policy if exists "Authenticated families view only related students"
on public.students;

create policy "Authenticated families view only related students"
on public.students
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles legacy_parent
    where legacy_parent.id = students.parent_id
      and legacy_parent.user_id = (select auth.uid())
      and public.mac_can_use_legacy_family_link(
        coalesce(students.organization_id, legacy_parent.organization_id)
      )
  )
  or exists (
    select 1
    from public.guardian_student_relationships relationship
    join public.guardians guardian
      on guardian.id = relationship.guardian_id
     and guardian.organization_id = relationship.organization_id
    join public.users enterprise_user on enterprise_user.person_id = guardian.person_id
    where relationship.student_id = students.id
      and relationship.organization_id = students.organization_id
      and relationship.educational_access
      and guardian.status = 'active'
      and enterprise_user.id = (select auth.uid())
      and enterprise_user.account_status = 'active'
      and (
        relationship.valid_from is null
        or relationship.valid_from <= public.mac_relationship_calendar_date(
          students.id,
          students.organization_id
        )
      )
      and (
        relationship.valid_until is null
        or relationship.valid_until >= public.mac_relationship_calendar_date(
          students.id,
          students.organization_id
        )
      )
  )
);

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
  v_site_timezone text;
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

  select site.timezone
  into v_site_timezone
    from public.sites site
    where site.id = p_site_id
      and site.organization_id = p_organization_id
      and site.status = 'active';

  if v_site_timezone is null then
    raise exception 'The selected site is not active in this organization';
  end if;

  if p_enrollment_start_date > (now() at time zone v_site_timezone)::date then
    raise exception 'Enrollment start date cannot be in the future';
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
  do nothing
  returning id into v_guardian_id;

  if v_guardian_id is null then
    select guardian.id
    into v_guardian_id
    from public.guardians guardian
    where guardian.organization_id = p_organization_id
      and guardian.person_id = v_guardian_person_id
      and guardian.status = 'active';
  end if;

  if v_guardian_id is null then
    raise exception 'The selected guardian is not active and must be reactivated separately';
  end if;

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
    null,
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
