begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(7);

insert into auth.users (id, email) values
  ('1a000000-0000-4000-8000-000000000001', 'organization-admin@example.test'),
  ('1a000000-0000-4000-8000-000000000002', 'invited-student@example.test');

insert into public.organizations (id, name, slug) values
  ('2a000000-0000-4000-8000-000000000001', 'Invitation Organization A', 'invitation-org-a'),
  ('2a000000-0000-4000-8000-000000000002', 'Invitation Organization B', 'invitation-org-b');

insert into public.sites (id, organization_id, name, code) values
  ('3a000000-0000-4000-8000-000000000001', '2a000000-0000-4000-8000-000000000001', 'Organization A Site', 'INV-A'),
  ('3a000000-0000-4000-8000-000000000002', '2a000000-0000-4000-8000-000000000002', 'Organization B Site', 'INV-B');

insert into public.users (id, account_status) values
  ('1a000000-0000-4000-8000-000000000001', 'active'),
  ('1a000000-0000-4000-8000-000000000002', 'invited');

insert into public.role_assignments (user_id, organization_id, role_key, status) values
  ('1a000000-0000-4000-8000-000000000001', '2a000000-0000-4000-8000-000000000001', 'organization_admin', 'active'),
  ('1a000000-0000-4000-8000-000000000002', '2a000000-0000-4000-8000-000000000001', 'student', 'active');

select lives_ok(
  $$insert into public.role_assignments (user_id, organization_id, site_id, role_key, status)
    values ('1a000000-0000-4000-8000-000000000002', '2a000000-0000-4000-8000-000000000001', '3a000000-0000-4000-8000-000000000001', 'student', 'inactive')$$,
  'a valid organization and site scope is accepted'
);

select throws_ok(
  $$insert into public.role_assignments (user_id, organization_id, site_id, role_key)
    values ('1a000000-0000-4000-8000-000000000002', '2a000000-0000-4000-8000-000000000001', '3a000000-0000-4000-8000-000000000002', 'student')$$,
  '23503',
  'insert or update on table "role_assignments" violates foreign key constraint "role_assignments_organization_site_fkey"',
  'a cross-tenant site assignment is rejected'
);

select throws_ok(
  $$insert into public.role_assignments (user_id, organization_id, role_key)
    values ('1a000000-0000-4000-8000-000000000002', '2a000000-0000-4000-8000-000000000001', 'platform_admin')$$,
  '23514',
  'new row for relation "role_assignments" violates check constraint "role_assignments_scope_valid_check"',
  'an invalid elevated role scope is rejected'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"1a000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select ok(
  not public.mac_has_role('student', '2a000000-0000-4000-8000-000000000001', null),
  'an invited user cannot use an active role assignment before activation'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"1a000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok(
  $$insert into public.role_assignments (user_id, organization_id, role_key, status)
    values ('1a000000-0000-4000-8000-000000000002', '2a000000-0000-4000-8000-000000000001', 'guardian', 'inactive')$$,
  'an organization administrator can create an invited participant assignment'
);
reset role;

select is(
  (
    select actor_user_id
    from public.role_assignment_events
    where assignment_id = (
      select id
      from public.role_assignments
      where user_id = '1a000000-0000-4000-8000-000000000002'
        and role_key = 'guardian'
    )
  ),
  '1a000000-0000-4000-8000-000000000001'::uuid,
  'the role-assignment audit records the organization administrator actor'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"1a000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(
  public.mac_has_role('organization_admin', '2a000000-0000-4000-8000-000000000001'::uuid, null),
  'an active organization administrator retains only their organization role'
);
reset role;

select * from finish();
rollback;
