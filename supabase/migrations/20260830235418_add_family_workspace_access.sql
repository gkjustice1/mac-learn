-- MAC Learn Family: read-only workspace access for active guardians.
-- Canonical guardian_student_relationships remain authoritative. The
-- parent-facing summary RPC intentionally excludes Tutor-only note fields.

create or replace function public.mac_family_can_view_organization(
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
    from public.role_assignments assignment
    join public.users enterprise_user on enterprise_user.id = assignment.user_id
    where assignment.user_id = (select auth.uid())
      and assignment.role_key = 'guardian'
      and assignment.organization_id = requested_organization_id
      and assignment.status = 'active'
      and assignment.valid_from <= now()
      and (assignment.valid_until is null or assignment.valid_until > now())
      and enterprise_user.account_status = 'active'
  );
$$;

revoke all on function public.mac_family_can_view_organization(uuid)
from public, anon;
grant execute on function public.mac_family_can_view_organization(uuid)
to authenticated;

create or replace function public.mac_family_can_access_student(
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
    from public.students student
    join public.guardian_student_relationships relationship
      on relationship.student_id = student.id
     and relationship.organization_id = student.organization_id
    join public.guardians guardian
      on guardian.id = relationship.guardian_id
     and guardian.organization_id = relationship.organization_id
    join public.users enterprise_user
      on enterprise_user.person_id = guardian.person_id
    where student.id = requested_student_id
      and student.enterprise_status = 'active'
      and guardian.status = 'active'
      and enterprise_user.id = (select auth.uid())
      and enterprise_user.account_status = 'active'
      and relationship.educational_access
      and (
        relationship.valid_from is null
        or relationship.valid_from <= public.mac_relationship_calendar_date(
          student.id,
          student.organization_id
        )
      )
      and (
        relationship.valid_until is null
        or relationship.valid_until >= public.mac_relationship_calendar_date(
          student.id,
          student.organization_id
        )
      )
      and (
        public.mac_has_role('guardian', student.organization_id, student.primary_site_id)
        or (
          student.primary_site_id is not null
          and public.mac_has_role('guardian', student.organization_id, null)
        )
      )
  );
$$;

revoke all on function public.mac_family_can_access_student(uuid)
from public, anon;
grant execute on function public.mac_family_can_access_student(uuid)
to authenticated;

drop policy if exists "Families view assigned organizations"
on public.organizations;
create policy "Families view assigned organizations"
on public.organizations
for select
to authenticated
using (public.mac_family_can_view_organization(id));

drop policy if exists "Families view assigned sites"
on public.sites;
create policy "Families view assigned sites"
on public.sites
for select
to authenticated
using (
  public.mac_has_role('guardian', organization_id, id)
  or public.mac_has_role('guardian', organization_id, null)
);

drop policy if exists "Families view assigned organization configuration"
on public.organization_configurations;
create policy "Families view assigned organization configuration"
on public.organization_configurations
for select
to authenticated
using (public.mac_family_can_view_organization(organization_id));

drop policy if exists "Families view linked sessions"
on public.sessions;
create policy "Families view linked sessions"
on public.sessions
for select
to authenticated
using (public.mac_family_can_access_student(student_id));

drop policy if exists "Families view linked progress reports"
on public.progress_reports;
create policy "Families view linked progress reports"
on public.progress_reports
for select
to authenticated
using (public.mac_family_can_access_student(student_id));

create or replace function public.mac_family_session_summaries()
returns table (
  id uuid,
  session_id uuid,
  student_id uuid,
  attendance_status public.attendance_status,
  parent_summary text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select
    note.id,
    note.session_id,
    session.student_id,
    note.attendance_status,
    note.parent_summary,
    note.created_at
  from public.session_notes note
  join public.sessions session on session.id = note.session_id
  where (select auth.uid()) is not null
    and public.mac_family_can_access_student(session.student_id)
  order by note.created_at desc;
$$;

revoke all on function public.mac_family_session_summaries()
from public, anon;
grant execute on function public.mac_family_session_summaries()
to authenticated;

comment on function public.mac_family_session_summaries() is
  'Returns attendance and parent_summary only for students linked to the active guardian; Tutor-private note fields are excluded.';
