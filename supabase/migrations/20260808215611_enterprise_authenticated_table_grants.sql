-- ============================================================
-- MAC LEARN
-- Authenticated Table Grants
--
-- Purpose:
-- Grant the authenticated PostgreSQL role the underlying table
-- privileges required for RLS policies to evaluate.
--
-- Row Level Security remains responsible for determining
-- which rows each authenticated user may access.
-- ============================================================


-- Ensure authenticated users can resolve objects in public.
grant usage on schema public to authenticated;


-- ------------------------------------------------------------
-- Enterprise foundation tables
-- ------------------------------------------------------------

grant select, insert, update, delete
on table public.organizations
to authenticated;

grant select, insert, update, delete
on table public.sites
to authenticated;

grant select, insert, update, delete
on table public.people
to authenticated;

grant select, insert, update, delete
on table public.users
to authenticated;

grant select, insert, update, delete
on table public.guardians
to authenticated;

grant select, insert, update, delete
on table public.guardian_student_relationships
to authenticated;

grant select, insert, update, delete
on table public.staff
to authenticated;

grant select, insert, update, delete
on table public.role_assignments
to authenticated;