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
    and public.mac_has_role('tutor', tutor.organization_id, tutor.site_id)
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
