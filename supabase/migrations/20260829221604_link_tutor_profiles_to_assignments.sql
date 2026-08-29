-- MAC Learn: keep active Tutor role assignments linked to tutor_profiles.

create or replace function public.mac_sync_tutor_profile_from_assignment()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_user_id uuid;
  selected_organization_id uuid;
  selected_site_id uuid;
begin
  target_user_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;

  select assignment.organization_id, assignment.site_id
  into selected_organization_id, selected_site_id
  from public.role_assignments as assignment
  where assignment.user_id = target_user_id
    and assignment.role_key = 'tutor'
    and assignment.status = 'active'
    and assignment.valid_from <= now()
    and (assignment.valid_until is null or assignment.valid_until > now())
  order by
    assignment.site_id nulls first,
    assignment.created_at desc
  limit 1;

  if found then
    insert into public.tutor_profiles (
      user_id,
      organization_id,
      site_id,
      person_id
    )
    select
      profile.id,
      selected_organization_id,
      selected_site_id,
      profile.person_id
    from public.profiles as profile
    where profile.user_id = target_user_id
    on conflict (user_id) do update
    set organization_id = excluded.organization_id,
        site_id = excluded.site_id,
        person_id = excluded.person_id,
        staff_id = case
          when tutor_profiles.organization_id is distinct from excluded.organization_id
            then null
          else tutor_profiles.staff_id
        end;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all on function public.mac_sync_tutor_profile_from_assignment()
from public, anon, authenticated, service_role;

drop trigger if exists role_assignments_sync_tutor_profile
on public.role_assignments;

create trigger role_assignments_sync_tutor_profile
after insert or update of role_key, status, organization_id, site_id
on public.role_assignments
for each row
execute function public.mac_sync_tutor_profile_from_assignment();

drop trigger if exists role_assignments_delete_sync_tutor_profile
on public.role_assignments;

create trigger role_assignments_delete_sync_tutor_profile
after delete
on public.role_assignments
for each row
execute function public.mac_sync_tutor_profile_from_assignment();

create or replace function public.mac_tutor_can_view_organization(
  requested_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.role_assignments as assignment
    join public.users as enterprise_user
      on enterprise_user.id = assignment.user_id
    where assignment.user_id = (select auth.uid())
      and assignment.role_key = 'tutor'
      and assignment.organization_id = requested_organization_id
      and assignment.status = 'active'
      and assignment.valid_from <= now()
      and (assignment.valid_until is null or assignment.valid_until > now())
      and enterprise_user.account_status = 'active'
  );
$$;

revoke all on function public.mac_tutor_can_view_organization(uuid)
from public, anon;
grant execute on function public.mac_tutor_can_view_organization(uuid)
to authenticated;

create or replace function public.mac_tutor_is_assigned_to_student(
  requested_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.sessions as session
    join public.students as student
      on student.id = session.student_id
    join public.role_assignments as assignment
      on assignment.user_id = (select auth.uid())
      and assignment.role_key = 'tutor'
      and assignment.organization_id = student.organization_id
      and (
        assignment.site_id is null
        or assignment.site_id = student.primary_site_id
      )
      and assignment.status = 'active'
      and assignment.valid_from <= now()
      and (assignment.valid_until is null or assignment.valid_until > now())
    join public.users as enterprise_user
      on enterprise_user.id = assignment.user_id
      and enterprise_user.account_status = 'active'
    where session.student_id = requested_student_id
      and session.tutor_id = public.mac_current_tutor_id()
  );
$$;

revoke all on function public.mac_tutor_is_assigned_to_student(uuid)
from public, anon;
grant execute on function public.mac_tutor_is_assigned_to_student(uuid)
to authenticated;

create or replace function public.mac_tutor_owns_session(
  requested_session_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.sessions as session
    where session.id = requested_session_id
      and session.tutor_id = public.mac_current_tutor_id()
      and public.mac_tutor_is_assigned_to_student(session.student_id)
  );
$$;

revoke all on function public.mac_tutor_owns_session(uuid)
from public, anon;
grant execute on function public.mac_tutor_owns_session(uuid)
to authenticated;

drop policy if exists "Tutors view assigned organizations"
on public.organizations;
create policy "Tutors view assigned organizations"
on public.organizations
for select
to authenticated
using (public.mac_tutor_can_view_organization(id));

drop policy if exists "Tutors view assigned sites"
on public.sites;
create policy "Tutors view assigned sites"
on public.sites
for select
to authenticated
using (public.mac_has_role('tutor', organization_id, id));

drop policy if exists "Tutors view assigned organization configuration"
on public.organization_configurations;
create policy "Tutors view assigned organization configuration"
on public.organization_configurations
for select
to authenticated
using (public.mac_tutor_can_view_organization(organization_id));

drop policy if exists "Tutors view assigned sessions"
on public.sessions;
create policy "Tutors view assigned sessions"
on public.sessions
for select
to authenticated
using (
  tutor_id = public.mac_current_tutor_id()
  and public.mac_tutor_is_assigned_to_student(student_id)
);

drop policy if exists "Tutors view their session notes"
on public.session_notes;
create policy "Tutors view their session notes"
on public.session_notes
for select
to authenticated
using (
  tutor_id = public.mac_current_tutor_id()
  and public.mac_tutor_owns_session(session_id)
);

drop policy if exists "Tutors view their progress reports"
on public.progress_reports;
create policy "Tutors view their progress reports"
on public.progress_reports
for select
to authenticated
using (
  tutor_id = public.mac_current_tutor_id()
  and public.mac_tutor_is_assigned_to_student(student_id)
);

insert into public.tutor_profiles (
  user_id,
  organization_id,
  site_id,
  person_id
)
select distinct on (profile.id)
  profile.id,
  assignment.organization_id,
  assignment.site_id,
  profile.person_id
from public.role_assignments as assignment
join public.profiles as profile
  on profile.user_id = assignment.user_id
where assignment.role_key = 'tutor'
  and assignment.status = 'active'
order by
  profile.id,
  assignment.site_id nulls first,
  assignment.created_at desc
on conflict (user_id) do update
set organization_id = excluded.organization_id,
    site_id = excluded.site_id,
    person_id = excluded.person_id,
    staff_id = case
      when tutor_profiles.organization_id is distinct from excluded.organization_id
        then null
      else tutor_profiles.staff_id
    end;
