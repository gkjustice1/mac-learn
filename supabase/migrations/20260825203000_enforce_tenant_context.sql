-- ============================================================
-- MAC Learn: tenant context enforcement
-- ============================================================

-- A site identifier is only meaningful inside its owning
-- organization. Composite keys let every dependent row enforce
-- that relationship without relying on an application check.

alter table public.sites
  add constraint sites_organization_id_id_key
  unique (organization_id, id);

alter table public.guardians
  add constraint guardians_organization_id_id_key
  unique (organization_id, id);

alter table public.students
  add constraint students_organization_id_id_key
  unique (organization_id, id);

alter table public.staff
  add constraint staff_organization_id_id_key
  unique (organization_id, id);


-- Earlier reconciliation added the organization and site columns
-- independently and left both nullable. Preserve those valid legacy
-- rows by deriving a missing organization from the referenced site
-- before the new consistency checks are validated. Existing non-null
-- conflicts are not rewritten; constraint validation will stop the
-- migration so they can be investigated rather than reassigned.

update public.profiles profile
set organization_id = site.organization_id
from public.sites site
where profile.site_id = site.id
  and profile.organization_id is null;

update public.students student
set organization_id = site.organization_id
from public.sites site
where student.primary_site_id = site.id
  and student.organization_id is null;

with student_relationship_organizations as (
  select
    relationship.student_id,
    min(relationship.organization_id) as organization_id
  from public.guardian_student_relationships relationship
  group by relationship.student_id
  having count(distinct relationship.organization_id) = 1
)
update public.students student
set organization_id = relationship.organization_id
from student_relationship_organizations relationship
where student.id = relationship.student_id
  and student.organization_id is null;

update public.tutor_profiles tutor
set organization_id = site.organization_id
from public.sites site
where tutor.site_id = site.id
  and tutor.organization_id is null;

update public.tutor_profiles tutor
set organization_id = staff.organization_id
from public.staff staff
where tutor.staff_id = staff.id
  and tutor.organization_id is null;


-- ------------------------------------------------------------
-- Organization/site consistency
-- ------------------------------------------------------------

alter table public.role_assignments
  drop constraint if exists role_assignments_site_id_fkey;

alter table public.role_assignments
  add constraint role_assignments_organization_site_fkey
  foreign key (organization_id, site_id)
  references public.sites(organization_id, id)
  on delete cascade;

alter table public.staff
  drop constraint if exists staff_primary_site_id_fkey;

alter table public.staff
  add constraint staff_organization_primary_site_fkey
  foreign key (organization_id, primary_site_id)
  references public.sites(organization_id, id)
  on delete set null (primary_site_id);

alter table public.profiles
  drop constraint if exists profiles_site_id_fkey;

alter table public.profiles
  add constraint profiles_site_requires_organization_check
  check (site_id is null or organization_id is not null)
  not valid;

alter table public.profiles
  validate constraint profiles_site_requires_organization_check;

alter table public.profiles
  add constraint profiles_organization_site_fkey
  foreign key (organization_id, site_id)
  references public.sites(organization_id, id)
  on delete set null (site_id)
  not valid;

alter table public.profiles
  validate constraint profiles_organization_site_fkey;

alter table public.students
  drop constraint if exists students_primary_site_id_fkey;

alter table public.students
  add constraint students_site_requires_organization_check
  check (primary_site_id is null or organization_id is not null)
  not valid;

alter table public.students
  validate constraint students_site_requires_organization_check;

alter table public.students
  add constraint students_organization_primary_site_fkey
  foreign key (organization_id, primary_site_id)
  references public.sites(organization_id, id)
  on delete set null (primary_site_id)
  not valid;

alter table public.students
  validate constraint students_organization_primary_site_fkey;

alter table public.tutor_profiles
  drop constraint if exists tutor_profiles_site_id_fkey;

alter table public.tutor_profiles
  add constraint tutor_profiles_site_requires_organization_check
  check (site_id is null or organization_id is not null)
  not valid;

alter table public.tutor_profiles
  validate constraint tutor_profiles_site_requires_organization_check;

alter table public.tutor_profiles
  add constraint tutor_profiles_organization_site_fkey
  foreign key (organization_id, site_id)
  references public.sites(organization_id, id)
  on delete set null (site_id)
  not valid;

alter table public.tutor_profiles
  validate constraint tutor_profiles_organization_site_fkey;


-- ------------------------------------------------------------
-- Organization consistency for other tenant-owned relations
-- ------------------------------------------------------------

alter table public.guardian_student_relationships
  drop constraint if exists guardian_student_relationships_guardian_id_fkey;

alter table public.guardian_student_relationships
  add constraint guardian_student_relationships_organization_guardian_fkey
  foreign key (organization_id, guardian_id)
  references public.guardians(organization_id, id)
  on delete cascade;

alter table public.guardian_student_relationships
  drop constraint if exists guardian_student_relationships_student_id_fkey;

alter table public.guardian_student_relationships
  add constraint guardian_student_relationships_organization_student_fkey
  foreign key (organization_id, student_id)
  references public.students(organization_id, id)
  on delete cascade;

alter table public.tutor_profiles
  drop constraint if exists tutor_profiles_staff_id_fkey;

alter table public.tutor_profiles
  add constraint tutor_profiles_staff_requires_organization_check
  check (staff_id is null or organization_id is not null)
  not valid;

alter table public.tutor_profiles
  validate constraint tutor_profiles_staff_requires_organization_check;

alter table public.tutor_profiles
  add constraint tutor_profiles_organization_staff_fkey
  foreign key (organization_id, staff_id)
  references public.staff(organization_id, id)
  on delete set null (staff_id)
  not valid;

alter table public.tutor_profiles
  validate constraint tutor_profiles_organization_staff_fkey;


-- ------------------------------------------------------------
-- Authoritative tenant-access helpers
-- ------------------------------------------------------------

create or replace function public.mac_can_access_organization(
  requested_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    requested_organization_id is not null
    and exists (
      select 1
      from public.organizations organization
      where organization.id = requested_organization_id
    )
    and exists (
      select 1
      from public.role_assignments assignment
      join public.users enterprise_user
        on enterprise_user.id = assignment.user_id
      where assignment.user_id = (select auth.uid())
        and enterprise_user.account_status = 'active'
        and assignment.status = 'active'
        and assignment.valid_from <= now()
        and (
          assignment.valid_until is null
          or assignment.valid_until > now()
        )
        and (
          (
            assignment.role_key = 'platform_admin'
            and assignment.organization_id is null
            and assignment.site_id is null
          )
          or assignment.organization_id = requested_organization_id
        )
    );
$$;

create or replace function public.mac_can_access_site(
  requested_organization_id uuid,
  requested_site_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    requested_organization_id is not null
    and requested_site_id is not null
    and exists (
      select 1
      from public.sites site
      where site.id = requested_site_id
        and site.organization_id = requested_organization_id
    )
    and exists (
      select 1
      from public.role_assignments assignment
      join public.users enterprise_user
        on enterprise_user.id = assignment.user_id
      where assignment.user_id = (select auth.uid())
        and enterprise_user.account_status = 'active'
        and assignment.status = 'active'
        and assignment.valid_from <= now()
        and (
          assignment.valid_until is null
          or assignment.valid_until > now()
        )
        and (
          (
            assignment.role_key = 'platform_admin'
            and assignment.organization_id is null
            and assignment.site_id is null
          )
          or (
            assignment.organization_id = requested_organization_id
            and (
              assignment.site_id is null
              or assignment.site_id = requested_site_id
            )
          )
        )
    );
$$;

-- Administrative checks must also prove the requested tenant
-- and site pair exists. In particular, an organization admin
-- cannot authorize an arbitrary site ID under their organization.

create or replace function public.mac_is_organization_admin(
  requested_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    exists (
      select 1
      from public.organizations organization
      where organization.id = requested_organization_id
    )
    and (
      public.mac_is_platform_admin()
      or public.mac_has_role(
        'organization_admin',
        requested_organization_id,
        null
      )
    );
$$;

create or replace function public.mac_is_site_admin(
  requested_organization_id uuid,
  requested_site_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    exists (
      select 1
      from public.sites site
      where site.id = requested_site_id
        and site.organization_id = requested_organization_id
    )
    and (
      public.mac_is_organization_admin(requested_organization_id)
      or public.mac_has_role(
        'site_admin',
        requested_organization_id,
        requested_site_id
      )
    );
$$;

revoke all on function public.mac_can_access_organization(uuid)
from public;

revoke all on function public.mac_can_access_site(uuid, uuid)
from public;

grant execute on function public.mac_can_access_organization(uuid)
to authenticated;

grant execute on function public.mac_can_access_site(uuid, uuid)
to authenticated;

comment on function public.mac_can_access_organization(uuid) is
  'Returns whether the authenticated active user has current access to an existing organization tenant.';

comment on function public.mac_can_access_site(uuid, uuid) is
  'Returns whether the authenticated active user has current access to an existing site in the requested organization tenant.';
