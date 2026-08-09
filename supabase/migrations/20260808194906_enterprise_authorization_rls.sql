-- ============================================================
-- MAC LEARN
-- Enterprise Authorization & RLS
--
-- Phase 1:
-- Establish reusable authorization helpers and conservative
-- organization/site-scoped administrator policies.
--
-- Student, guardian, tutor, and staff operational access
-- will be added deliberately in later policy migrations.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Authorization helper: enterprise user exists
-- ------------------------------------------------------------

create or replace function public.mac_is_enterprise_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.account_status = 'active'
  );
$$;


-- ------------------------------------------------------------
-- 2. Authorization helper: user has active role
--
-- Supports:
-- - organization-scoped roles
-- - site-scoped roles
-- - platform roles where organization_id is null
-- ------------------------------------------------------------

create or replace function public.mac_has_role(
  requested_role text,
  requested_organization_id uuid default null,
  requested_site_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.role_assignments ra
    join public.users u
      on u.id = ra.user_id
    where ra.user_id = auth.uid()
      and u.account_status = 'active'
      and ra.status = 'active'
      and ra.role_key = requested_role

      and (
        ra.valid_from is null
        or ra.valid_from <= now()
      )

      and (
        ra.valid_until is null
        or ra.valid_until > now()
      )

      and (
        requested_organization_id is null
        or ra.organization_id = requested_organization_id
        or ra.organization_id is null
      )

      and (
        requested_site_id is null
        or ra.site_id = requested_site_id
        or ra.site_id is null
      )
  );
$$;


-- ------------------------------------------------------------
-- 3. Authorization helper: platform administrator
-- ------------------------------------------------------------

create or replace function public.mac_is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.mac_has_role('platform_admin', null, null);
$$;


-- ------------------------------------------------------------
-- 4. Authorization helper: organization administrator
-- ------------------------------------------------------------

create or replace function public.mac_is_organization_admin(
  requested_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.mac_is_platform_admin()
    or public.mac_has_role(
      'organization_admin',
      requested_organization_id,
      null
    );
$$;


-- ------------------------------------------------------------
-- 5. Authorization helper: site administrator
-- ------------------------------------------------------------

create or replace function public.mac_is_site_admin(
  requested_organization_id uuid,
  requested_site_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.mac_is_organization_admin(requested_organization_id)
    or public.mac_has_role(
      'site_admin',
      requested_organization_id,
      requested_site_id
    );
$$;


-- ------------------------------------------------------------
-- 6. Lock down direct execution surface
--
-- Authenticated users may call these helpers through policies.
-- Anonymous users should not.
-- ------------------------------------------------------------

revoke all on function public.mac_is_enterprise_user()
from public;

revoke all on function public.mac_has_role(text, uuid, uuid)
from public;

revoke all on function public.mac_is_platform_admin()
from public;

revoke all on function public.mac_is_organization_admin(uuid)
from public;

revoke all on function public.mac_is_site_admin(uuid, uuid)
from public;

grant execute on function public.mac_is_enterprise_user()
to authenticated;

grant execute on function public.mac_has_role(text, uuid, uuid)
to authenticated;

grant execute on function public.mac_is_platform_admin()
to authenticated;

grant execute on function public.mac_is_organization_admin(uuid)
to authenticated;

grant execute on function public.mac_is_site_admin(uuid, uuid)
to authenticated;


-- ------------------------------------------------------------
-- 7. Organizations
--
-- Platform admins: full access
-- Organization admins: view their organization
-- ------------------------------------------------------------

drop policy if exists
  "Enterprise admins view organizations"
on public.organizations;

create policy
  "Enterprise admins view organizations"
on public.organizations
for select
to authenticated
using (
  public.mac_is_platform_admin()
  or public.mac_is_organization_admin(id)
);


drop policy if exists
  "Platform admins manage organizations"
on public.organizations;

create policy
  "Platform admins manage organizations"
on public.organizations
for all
to authenticated
using (
  public.mac_is_platform_admin()
)
with check (
  public.mac_is_platform_admin()
);


-- ------------------------------------------------------------
-- 8. Sites
--
-- Organization admins can manage sites in their organization.
-- Site admins can view their assigned site.
-- ------------------------------------------------------------

drop policy if exists
  "Enterprise admins view sites"
on public.sites;

create policy
  "Enterprise admins view sites"
on public.sites
for select
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
  or public.mac_is_site_admin(organization_id, id)
);


drop policy if exists
  "Organization admins manage sites"
on public.sites;

create policy
  "Organization admins manage sites"
on public.sites
for all
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
)
with check (
  public.mac_is_organization_admin(organization_id)
);


-- ------------------------------------------------------------
-- 9. People
--
-- Phase 1 intentionally restricts canonical person records
-- to platform administrators.
--
-- More granular guardian/student/staff access comes later.
-- ------------------------------------------------------------

drop policy if exists
  "Platform admins manage people"
on public.people;

create policy
  "Platform admins manage people"
on public.people
for all
to authenticated
using (
  public.mac_is_platform_admin()
)
with check (
  public.mac_is_platform_admin()
);


-- ------------------------------------------------------------
-- 10. Enterprise Users
--
-- Users may view their own enterprise identity.
-- Platform admins may manage all enterprise users.
-- ------------------------------------------------------------

drop policy if exists
  "Users view own enterprise identity"
on public.users;

create policy
  "Users view own enterprise identity"
on public.users
for select
to authenticated
using (
  id = auth.uid()
  or public.mac_is_platform_admin()
);


drop policy if exists
  "Platform admins manage enterprise users"
on public.users;

create policy
  "Platform admins manage enterprise users"
on public.users
for all
to authenticated
using (
  public.mac_is_platform_admin()
)
with check (
  public.mac_is_platform_admin()
);


-- ------------------------------------------------------------
-- 11. Guardians
--
-- Organization administrators may manage guardian records
-- belonging to their organization.
-- ------------------------------------------------------------

drop policy if exists
  "Organization admins manage guardians"
on public.guardians;

create policy
  "Organization admins manage guardians"
on public.guardians
for all
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
)
with check (
  public.mac_is_organization_admin(organization_id)
);


-- ------------------------------------------------------------
-- 12. Guardian / Student Relationships
-- ------------------------------------------------------------

drop policy if exists
  "Organization admins manage guardian student relationships"
on public.guardian_student_relationships;

create policy
  "Organization admins manage guardian student relationships"
on public.guardian_student_relationships
for all
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
)
with check (
  public.mac_is_organization_admin(organization_id)
);


-- ------------------------------------------------------------
-- 13. Staff
--
-- Organization admins may manage organization staff.
-- Site admins may view staff assigned to their site.
-- ------------------------------------------------------------

drop policy if exists
  "Enterprise admins view staff"
on public.staff;

create policy
  "Enterprise admins view staff"
on public.staff
for select
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
  or (
    primary_site_id is not null
    and public.mac_is_site_admin(
      organization_id,
      primary_site_id
    )
  )
);


drop policy if exists
  "Organization admins manage staff"
on public.staff;

create policy
  "Organization admins manage staff"
on public.staff
for all
to authenticated
using (
  public.mac_is_organization_admin(organization_id)
)
with check (
  public.mac_is_organization_admin(organization_id)
);


-- ------------------------------------------------------------
-- 14. Role Assignments
--
-- Platform admins can manage all assignments.
-- Organization admins can manage assignments scoped to their
-- organization.
--
-- Site administrators DO NOT receive role-management rights.
-- ------------------------------------------------------------

drop policy if exists
  "Enterprise admins view role assignments"
on public.role_assignments;

create policy
  "Enterprise admins view role assignments"
on public.role_assignments
for select
to authenticated
using (
  public.mac_is_platform_admin()
  or (
    organization_id is not null
    and public.mac_is_organization_admin(organization_id)
  )
);


drop policy if exists
  "Platform admins manage role assignments"
on public.role_assignments;

create policy
  "Platform admins manage role assignments"
on public.role_assignments
for all
to authenticated
using (
  public.mac_is_platform_admin()
)
with check (
  public.mac_is_platform_admin()
);


drop policy if exists
  "Organization admins manage organization roles"
on public.role_assignments;

create policy
  "Organization admins manage organization roles"
on public.role_assignments
for all
to authenticated
using (
  organization_id is not null
  and public.mac_is_organization_admin(organization_id)
)
with check (
  organization_id is not null
  and public.mac_is_organization_admin(organization_id)

  -- Organization administrators must not create or modify
  -- platform-level administrative assignments.
  and role_key not in (
    'platform_admin',
    'platform_support'
  )
);


-- ------------------------------------------------------------
-- 15. Explicit RLS confirmation
-- ------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.sites enable row level security;
alter table public.people enable row level security;
alter table public.users enable row level security;
alter table public.guardians enable row level security;
alter table public.guardian_student_relationships
  enable row level security;
alter table public.staff enable row level security;
alter table public.role_assignments enable row level security;