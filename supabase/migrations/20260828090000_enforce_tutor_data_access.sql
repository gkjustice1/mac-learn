-- MAC Learn: tutor access is limited to explicitly assigned sessions.

create or replace function public.mac_current_tutor_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $tutor$
  select tutor.id
  from public.tutor_profiles tutor
  join public.profiles profile on profile.id = tutor.user_id
  join public.users enterprise_user on enterprise_user.id = auth.uid()
  where profile.user_id = auth.uid()
    and enterprise_user.account_status = 'active'
    and (
      public.mac_has_role('tutor', tutor.organization_id, tutor.site_id)
      or (
        tutor.site_id is not null
        and public.mac_has_role('tutor', tutor.organization_id, null)
      )
    )
  limit 1;
$tutor$;

revoke all on function public.mac_current_tutor_id() from public;
grant execute on function public.mac_current_tutor_id() to authenticated;

create or replace function public.mac_tutor_is_assigned_to_student(requested_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $assignment$
  select exists (
    select 1
    from public.sessions session
    where session.student_id = requested_student_id
      and session.tutor_id = public.mac_current_tutor_id()
  );
$assignment$;

revoke all on function public.mac_tutor_is_assigned_to_student(uuid) from public;
grant execute on function public.mac_tutor_is_assigned_to_student(uuid) to authenticated;

create or replace function public.mac_tutor_owns_session(requested_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $session$
  select exists (
    select 1
    from public.sessions session
    where session.id = requested_session_id
      and session.tutor_id = public.mac_current_tutor_id()
  );
$session$;

revoke all on function public.mac_tutor_owns_session(uuid) from public;
grant execute on function public.mac_tutor_owns_session(uuid) to authenticated;

create policy "Tutors view their own profile"
on public.tutor_profiles for select to authenticated
using (id = public.mac_current_tutor_id());

create policy "Tutors update their own profile"
on public.tutor_profiles for update to authenticated
using (id = public.mac_current_tutor_id())
with check (id = public.mac_current_tutor_id());

-- A tutor may maintain public professional information, but approval,
-- compensation, identity, staff, and tenant mappings remain administrative.
revoke update on table public.tutor_profiles from authenticated;
grant update (bio, subjects, grade_levels) on table public.tutor_profiles to authenticated;

create or replace function public.mac_can_manage_tutor_profile(
  requested_tutor_id uuid,
  requested_organization_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $tutor_admin$
  select exists (
    select 1
    from public.tutor_profiles tutor
    where tutor.id = requested_tutor_id
      and (
        public.current_user_role() = 'admin'
        or public.mac_is_platform_admin()
        or (
          tutor.organization_id is not null
          and public.mac_is_organization_admin(tutor.organization_id)
          and (
            requested_organization_id is null
            or requested_organization_id = tutor.organization_id
          )
        )
        or (
          tutor.organization_id is null
          and requested_organization_id is not null
          and public.mac_is_organization_admin(requested_organization_id)
        )
      )
  );
$tutor_admin$;

revoke all on function public.mac_can_manage_tutor_profile(uuid, uuid) from public;
grant execute on function public.mac_can_manage_tutor_profile(uuid, uuid) to authenticated;

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
begin
  if not public.mac_can_manage_tutor_profile(
    requested_tutor_id,
    requested_organization_id
  ) then
    raise exception 'not authorized to manage tutor profile' using errcode = '42501';
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
begin
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

create policy "Enterprise administrators view tutor profiles"
on public.tutor_profiles for select to authenticated
using (
  public.mac_is_platform_admin()
  or (
    organization_id is not null
    and public.mac_is_organization_admin(organization_id)
  )
);

create policy "Tutors manage their availability"
on public.tutor_availability for all to authenticated
using (tutor_id = public.mac_current_tutor_id())
with check (tutor_id = public.mac_current_tutor_id());

create policy "Tutors view assigned sessions"
on public.sessions for select to authenticated
using (tutor_id = public.mac_current_tutor_id());

create policy "Tutors view assigned students"
on public.students for select to authenticated
using (public.mac_tutor_is_assigned_to_student(id));

create policy "Tutors view their session notes"
on public.session_notes for select to authenticated
using (tutor_id = public.mac_current_tutor_id());

create policy "Tutors write their session notes"
on public.session_notes for insert to authenticated
with check (
  tutor_id = public.mac_current_tutor_id()
  and public.mac_tutor_owns_session(session_id)
);

create policy "Tutors update their session notes"
on public.session_notes for update to authenticated
using (tutor_id = public.mac_current_tutor_id())
with check (
  tutor_id = public.mac_current_tutor_id()
  and public.mac_tutor_owns_session(session_id)
);

create policy "Tutors view their progress reports"
on public.progress_reports for select to authenticated
using (tutor_id = public.mac_current_tutor_id());

create policy "Tutors write assigned student progress reports"
on public.progress_reports for insert to authenticated
with check (
  tutor_id = public.mac_current_tutor_id()
  and public.mac_tutor_is_assigned_to_student(student_id)
);

create policy "Tutors update their progress reports"
on public.progress_reports for update to authenticated
using (tutor_id = public.mac_current_tutor_id())
with check (
  tutor_id = public.mac_current_tutor_id()
  and public.mac_tutor_is_assigned_to_student(student_id)
);
