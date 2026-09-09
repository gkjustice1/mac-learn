-- Preserve the already-applied reconciliation migration and append the PostgreSQL 17
-- MAINTAIN and trigger-helper ACL corrections needed for production-equivalent replay.

grant maintain on table
  public.classroom_educators,
  public.classroom_student_enrollments,
  public.classrooms,
  public.educator_instructional_records,
  public.guardian_student_relationships,
  public.guardians,
  public.homework_uploads,
  public.organization_configurations,
  public.organizations,
  public.payments,
  public.people,
  public.profiles,
  public.progress_reports,
  public.role_assignment_events,
  public.role_assignments,
  public.session_notes,
  public.sessions,
  public.sites,
  public.staff,
  public.students,
  public.subjects,
  public.tutor_availability,
  public.tutor_profiles,
  public.users
  to anon;

grant maintain on table
  public.classroom_educators,
  public.classroom_student_enrollments,
  public.classrooms,
  public.educator_instructional_records,
  public.guardian_student_relationships,
  public.guardians,
  public.homework_uploads,
  public.organization_configurations,
  public.organizations,
  public.payments,
  public.people,
  public.profiles,
  public.progress_reports,
  public.role_assignments,
  public.session_notes,
  public.sessions,
  public.sites,
  public.staff,
  public.students,
  public.subjects,
  public.student_enrollment_events,
  public.tutor_availability,
  public.tutor_profiles,
  public.users
  to authenticated;

grant maintain on all tables in schema public to service_role;

revoke execute on function public.mac_set_updated_at() from anon, authenticated, service_role;
grant execute on function public.mac_set_updated_at() to public;
