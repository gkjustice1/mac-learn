-- ============================================================
-- MAC LEARN
-- Harden Role Assignment Uniqueness
--
-- Purpose:
-- 1. Prevent duplicate active role assignments.
-- 2. Preserve historical inactive, expired, and revoked records.
-- 3. Treat NULL platform-level scope values as equal.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Preflight duplicate check
--
-- Abort the migration if duplicate active assignments already
-- exist for the same user, role, organization, and site scope.
-- PostgreSQL GROUP BY groups NULL scope values together, which
-- lets this check detect duplicate platform-level assignments.
-- ------------------------------------------------------------

do $$
begin
  if exists (
    select 1
    from public.role_assignments
    where status = 'active'
    group by
      user_id,
      role_key,
      organization_id,
      site_id
    having count(*) > 1
  ) then
    raise exception
      'Cannot enforce role assignment uniqueness: duplicate active role assignments already exist.';
  end if;
end
$$;


-- ------------------------------------------------------------
-- 2. Enforce one active assignment per exact role scope
--
-- NULLS NOT DISTINCT is required so platform-level assignments
-- with organization_id = NULL and site_id = NULL are treated as
-- the same scope for uniqueness enforcement.
--
-- Historical assignments remain allowed when their status is:
-- inactive, expired, or revoked.
-- ------------------------------------------------------------

create unique index if not exists
  role_assignments_one_active_scope_uidx
on public.role_assignments (
  user_id,
  role_key,
  organization_id,
  site_id
)
nulls not distinct
where status = 'active';


-- ------------------------------------------------------------
-- 3. Documentation
-- ------------------------------------------------------------

comment on index
  public.role_assignments_one_active_scope_uidx
is
  'Prevents duplicate active MAC Learn role assignments for the same user, role, and exact organization/site scope while preserving inactive, expired, and revoked history.';