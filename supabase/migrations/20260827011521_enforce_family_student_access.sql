-- MAC Learn: family-to-student access context
--
-- A guardian may view only a student connected to their authenticated
-- enterprise identity by an active relationship that grants educational
-- access. The legacy students.parent_id link remains read-compatible while
-- existing records are migrated to guardian_student_relationships.

drop policy if exists "Admins manage students" on public.students;
drop policy if exists "Parents view own students" on public.students;
drop policy if exists "Parents create own students" on public.students;

create policy "Organization admins manage students"
on public.students
for all
to authenticated
using (
  organization_id is not null
  and public.mac_is_organization_admin(organization_id)
)
with check (
  organization_id is not null
  and public.mac_is_organization_admin(organization_id)
);

create policy "Authenticated guardians view their own guardian records"
on public.guardians
for select
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
  or exists (
    select 1
    from public.users enterprise_user
    where enterprise_user.id = (select auth.uid())
      and enterprise_user.account_status = 'active'
      and enterprise_user.person_id = guardians.person_id
  )
);

create policy "Authenticated guardians view active educational relationships"
on public.guardian_student_relationships
for select
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
  or exists (
    select 1
    from public.guardians guardian
    join public.users enterprise_user
      on enterprise_user.person_id = guardian.person_id
    where guardian.id = guardian_student_relationships.guardian_id
      and guardian.organization_id = guardian_student_relationships.organization_id
      and guardian.status = 'active'
      and enterprise_user.id = (select auth.uid())
      and enterprise_user.account_status = 'active'
      and guardian_student_relationships.educational_access
      and (
        guardian_student_relationships.valid_from is null
        or guardian_student_relationships.valid_from <= current_date
      )
      and (
        guardian_student_relationships.valid_until is null
        or guardian_student_relationships.valid_until >= current_date
      )
  )
);

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
  )
  or exists (
    select 1
    from public.guardian_student_relationships relationship
    join public.guardians guardian
      on guardian.id = relationship.guardian_id
     and guardian.organization_id = relationship.organization_id
    join public.users enterprise_user
      on enterprise_user.person_id = guardian.person_id
    where relationship.student_id = students.id
      and relationship.organization_id = students.organization_id
      and relationship.educational_access
      and guardian.status = 'active'
      and enterprise_user.id = (select auth.uid())
      and enterprise_user.account_status = 'active'
      and (
        relationship.valid_from is null
        or relationship.valid_from <= current_date
      )
      and (
        relationship.valid_until is null
        or relationship.valid_until >= current_date
      )
  )
);

comment on policy "Authenticated guardians view their own guardian records"
on public.guardians is
  'A guardian can view only their own enterprise guardian record; organization and platform admins retain management access.';

comment on policy "Authenticated guardians view active educational relationships"
on public.guardian_student_relationships is
  'A guardian can view only active, currently valid relationships that grant educational access.';

comment on policy "Authenticated families view only related students"
on public.students is
  'Family access requires the legacy parent link or an active guardian relationship with educational access.';
