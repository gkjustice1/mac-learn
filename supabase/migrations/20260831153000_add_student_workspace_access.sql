-- MAC Learn Student: read-only workspace access for active student identities.
-- The canonical link is users.person_id -> students.person_id, constrained by
-- the student's active role assignment, organization, site, and enrollment.

create or replace function public.mac_current_student_ids()
returns setof uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select student.id
  from public.users enterprise_user
  join public.students student on student.person_id = enterprise_user.person_id
  join public.role_assignments assignment
    on assignment.user_id = enterprise_user.id
   and assignment.role_key = 'student'
   and assignment.organization_id = student.organization_id
   and (assignment.site_id is null or assignment.site_id = student.primary_site_id)
  where enterprise_user.id = (select auth.uid())
    and enterprise_user.account_status = 'active'
    and student.enterprise_status = 'active'
    and (student.enrollment_start_date is null or student.enrollment_start_date <= current_date)
    and (student.enrollment_end_date is null or student.enrollment_end_date >= current_date)
    and assignment.status = 'active'
    and assignment.valid_from <= now()
    and (assignment.valid_until is null or assignment.valid_until > now())
$$;

revoke all on function public.mac_current_student_ids() from public, anon;
grant execute on function public.mac_current_student_ids() to authenticated;

drop policy if exists "Students view their sessions" on public.sessions;
create policy "Students view their sessions"
on public.sessions for select to authenticated
using (student_id in (select public.mac_current_student_ids()));

drop policy if exists "Students view their assignments" on public.homework_uploads;
create policy "Students view their assignments"
on public.homework_uploads for select to authenticated
using (student_id in (select public.mac_current_student_ids()));

drop policy if exists "Students view their progress reports" on public.progress_reports;
create policy "Students view their progress reports"
on public.progress_reports for select to authenticated
using (student_id in (select public.mac_current_student_ids()));

grant select on public.students, public.sessions, public.homework_uploads,
  public.progress_reports, public.classrooms, public.classroom_student_enrollments,
  public.educator_instructional_records, public.subjects to authenticated;
revoke insert, update, delete on public.homework_uploads from authenticated;

create or replace function public.mac_student_feedback()
returns table (
  id uuid,
  session_id uuid,
  student_id uuid,
  attendance_status public.attendance_status,
  skills_covered text,
  performance_notes text,
  homework_assigned text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select note.id, note.session_id, session.student_id,
    note.attendance_status, note.skills_covered, note.performance_notes,
    note.homework_assigned, note.created_at
  from public.session_notes note
  join public.sessions session on session.id = note.session_id
  where (select auth.uid()) is not null
    and session.student_id in (select public.mac_current_student_ids())
  order by note.created_at desc
$$;

revoke all on function public.mac_student_feedback() from public, anon;
grant execute on function public.mac_student_feedback() to authenticated;

comment on function public.mac_current_student_ids() is
  'Resolves canonical active enrollments for the authenticated Student through the shared enterprise person identity and exact active role scope.';
comment on function public.mac_student_feedback() is
  'Returns student-facing attendance, skills, performance, and homework feedback while excluding Tutor-private and guardian-only notes.';
