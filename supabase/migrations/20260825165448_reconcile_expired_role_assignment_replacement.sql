-- ============================================================
-- MAC LEARN
-- Reconcile Expired Role Assignments Before Replacement
--
-- Purpose:
-- 1. Transition an exact-scope time-expired active assignment
--    before a replacement is inserted.
-- 2. Keep the uniqueness index as the final concurrency guard.
-- 3. Preserve RLS by running with the invoking user's privileges.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Reconcile an expired exact-scope assignment
-- ------------------------------------------------------------

create or replace function
  public.mac_expire_conflicting_role_assignment()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.status = 'active' then
    update public.role_assignments
    set status = 'expired'
    where user_id = new.user_id
      and role_key = new.role_key
      and organization_id is not distinct from new.organization_id
      and site_id is not distinct from new.site_id
      and status = 'active'
      and valid_until is not null
      and valid_until <= now();
  end if;

  return new;
end;
$$;

revoke all
on function public.mac_expire_conflicting_role_assignment()
from public;


-- ------------------------------------------------------------
-- 2. Apply reconciliation to every assignment write path
-- ------------------------------------------------------------

drop trigger if exists
  role_assignments_expire_conflict_before_insert
on public.role_assignments;

create trigger
  role_assignments_expire_conflict_before_insert
before insert on public.role_assignments
for each row
execute function
  public.mac_expire_conflicting_role_assignment();


-- ------------------------------------------------------------
-- 3. Documentation
-- ------------------------------------------------------------

comment on function
  public.mac_expire_conflicting_role_assignment()
is
  'Before an active role assignment is inserted, transitions an exact-scope active assignment whose valid_until has elapsed to expired.';

comment on trigger
  role_assignments_expire_conflict_before_insert
on public.role_assignments
is
  'Allows safe replacement of an exact-scope role assignment after valid_until while preserving the active-scope uniqueness index.';
