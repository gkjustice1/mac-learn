-- ============================================================
-- MAC LEARN
-- Harden Role Scope Authorization
--
-- Purpose:
-- 1. Require exact organization/site scope matching.
-- 2. Prevent malformed elevated administrative assignments.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Replace wildcard role matching with exact scope matching.
--
-- Rules:
-- - NULL requested organization => assignment organization
--   must also be NULL.
-- - Non-NULL requested organization => exact match required.
-- - NULL requested site => assignment site must also be NULL.
-- - Non-NULL requested site => exact match required.
--
-- This prevents a null-scoped organization/site role from
-- accidentally behaving as a broader role.
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

      and ra.valid_from <= now()

      and (
        ra.valid_until is null
        or ra.valid_until > now()
      )

      and (
        (
          requested_organization_id is null
          and ra.organization_id is null
        )
        or
        (
          requested_organization_id is not null
          and ra.organization_id = requested_organization_id
        )
      )

      and (
        (
          requested_site_id is null
          and ra.site_id is null
        )
        or
        (
          requested_site_id is not null
          and ra.site_id = requested_site_id
        )
      )
  );
$$;


-- ------------------------------------------------------------
-- 2. Prevent malformed role scopes.
--
-- Platform roles:
--   organization_id = NULL
--   site_id = NULL
--
-- Organization roles:
--   organization_id required
--   site_id = NULL
--
-- Site roles:
--   organization_id required
--   site_id required
--
-- Operational roles may be organization-scoped or site-scoped,
-- but they may never be completely unscoped.
-- ------------------------------------------------------------

alter table public.role_assignments
  drop constraint if exists
    role_assignments_scope_valid_check;

alter table public.role_assignments
  add constraint role_assignments_scope_valid_check
  check (
    case

      when role_key in (
        'platform_admin',
        'platform_support'
      )
      then
        organization_id is null
        and site_id is null

      when role_key in (
        'organization_admin',
        'academic_lead'
      )
      then
        organization_id is not null
        and site_id is null

      when role_key = 'site_admin'
      then
        organization_id is not null
        and site_id is not null

      when role_key in (
        'student',
        'guardian',
        'tutor',
        'teacher'
      )
      then
        organization_id is not null

      else false
    end
  );


-- ------------------------------------------------------------
-- 3. Documentation
-- ------------------------------------------------------------

comment on constraint role_assignments_scope_valid_check
on public.role_assignments is
  'Enforces valid MAC LEARN authorization scope for platform, organization, site, and operational roles.';