-- Reconcile local/fresh-deployment ACLs to the effective production ACL state.
-- This migration intentionally changes grants only. It does not alter data or RLS policies.

revoke all privileges on all tables in schema public from public, anon, authenticated, service_role;

-- anon: production exposes only REFERENCES/TRIGGER/TRUNCATE on these legacy/application tables.
grant references, trigger, truncate on table
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

-- authenticated: reproduce production table-level grants exactly.
grant delete, insert, references, select, trigger, truncate, update on table
  public.classroom_educators,
  public.classroom_student_enrollments,
  public.classrooms,
  public.educator_instructional_records,
  public.guardian_student_relationships,
  public.guardians,
  public.organizations,
  public.people,
  public.role_assignments,
  public.sites,
  public.staff,
  public.users
  to authenticated;

grant references, select, trigger, truncate on table
  public.homework_uploads,
  public.organization_configurations,
  public.profiles,
  public.sessions,
  public.student_enrollment_events,
  public.students,
  public.subjects
  to authenticated;

grant insert, references, select, trigger, truncate on table
  public.progress_reports,
  public.session_notes,
  public.tutor_availability
  to authenticated;

grant select on table
  public.role_assignment_events,
  public.session_status_events
  to authenticated;

grant references, trigger, truncate on table
  public.payments,
  public.tutor_profiles
  to authenticated;

-- Production uses column-scoped UPDATE grants for self-service profile fields.
grant update (full_name, phone) on table public.profiles to authenticated;
grant update (bio, subjects, grade_levels) on table public.tutor_profiles to authenticated;

-- service_role: production does not have blanket DML on application tables.
grant references, trigger, truncate on all tables in schema public to service_role;
revoke references, trigger, truncate on table public.mac_reads_audio_assets from anon, authenticated;
grant select, update on table public.organization_configurations to service_role;

-- Functions: revoke the default surface, then restore production's exact normalized ACLs.
revoke execute on all functions in schema public from public, anon, authenticated, service_role;

-- Trigger helper retains PostgreSQL's production-default PUBLIC EXECUTE semantics.
-- anon, authenticated, and service_role inherit this privilege through PUBLIC; they
-- must not receive separate direct grants.
grant execute on function public.mac_set_updated_at() to public;

-- Service-only invitation identity helpers.
grant execute on function public.mac_create_invited_enterprise_identity(uuid,text,text,text,uuid,uuid) to service_role;
grant execute on function public.mac_cleanup_invited_enterprise_identity(uuid) to service_role;

-- Authenticated application/RPC surface.
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.mac_activate_invited_enterprise_user() to authenticated;
grant execute on function public.mac_admin_clear_tutor_profile_fields(uuid,boolean,boolean,boolean,boolean) to authenticated;
grant execute on function public.mac_admin_enroll_student(text,text,text,text,uuid,uuid,date,text,uuid,text) to authenticated;
grant execute on function public.mac_admin_link_invited_student_login(uuid,uuid,text) to authenticated;
grant execute on function public.mac_admin_search_guardians(uuid,uuid,text) to authenticated;
grant execute on function public.mac_admin_update_tutor_profile(uuid,approval_status,numeric,uuid,uuid,uuid,uuid,uuid) to authenticated;
grant execute on function public.mac_admin_validate_student_login_invitation(uuid,text) to authenticated;
grant execute on function public.mac_can_access_organization(uuid) to authenticated;
grant execute on function public.mac_can_access_site(uuid,uuid) to authenticated;
grant execute on function public.mac_can_manage_tutor_profile(uuid,uuid) to authenticated;
grant execute on function public.mac_can_use_legacy_admin_access() to authenticated;
grant execute on function public.mac_can_use_legacy_family_link(uuid) to authenticated;
grant execute on function public.mac_classroom_calendar_date(uuid) to authenticated;
grant execute on function public.mac_current_student_ids() to authenticated;
grant execute on function public.mac_current_tutor_id() to authenticated;
grant execute on function public.mac_current_user_roles() to authenticated;
grant execute on function public.mac_educator_can_access_student(uuid,uuid) to authenticated;
grant execute on function public.mac_expire_role_assignment(uuid,text) to authenticated;
grant execute on function public.mac_family_can_access_student(uuid) to authenticated;
grant execute on function public.mac_family_can_view_organization(uuid) to authenticated;
grant execute on function public.mac_family_session_summaries() to authenticated;
grant execute on function public.mac_family_students() to authenticated;
grant execute on function public.mac_get_educator_classroom_page(integer,integer) to authenticated;
grant execute on function public.mac_get_educator_instructional_record_page(integer,integer) to authenticated;
grant execute on function public.mac_get_educator_student_page(integer,integer) to authenticated;
grant execute on function public.mac_has_role(text,uuid,uuid) to authenticated;
grant execute on function public.mac_is_active_classroom_educator(uuid) to authenticated;
grant execute on function public.mac_is_active_educator_scope(uuid,uuid) to authenticated;
grant execute on function public.mac_is_enterprise_user() to authenticated;
grant execute on function public.mac_is_organization_admin(uuid) to authenticated;
grant execute on function public.mac_is_platform_admin() to authenticated;
grant execute on function public.mac_is_site_admin(uuid,uuid) to authenticated;
grant execute on function public.mac_is_site_classroom_admin(uuid,uuid) to authenticated;
grant execute on function public.mac_platform_admin_schedule_session(uuid,uuid,uuid,timestamptz,timestamptz,text) to authenticated;
grant execute on function public.mac_platform_admin_student_options() to authenticated;
grant execute on function public.mac_platform_admin_tutor_options() to authenticated;
grant execute on function public.mac_relationship_calendar_date(uuid,uuid) to authenticated;
grant execute on function public.mac_renew_role_assignment(uuid,timestamptz,text) to authenticated;
grant execute on function public.mac_revoke_role_assignment(uuid,text) to authenticated;
grant execute on function public.mac_student_feedback() to authenticated;
grant execute on function public.mac_tutor_can_view_organization(uuid) to authenticated;
grant execute on function public.mac_tutor_is_assigned_to_student(uuid) to authenticated;
grant execute on function public.mac_tutor_owns_session(uuid) to authenticated;
