begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(9);

select has_function(
  'public',
  'mac_sync_tutor_profile_from_assignment',
  array[]::text[],
  'Tutor profile synchronization function exists'
);

select ok(
  not has_function_privilege('anon', 'public.mac_sync_tutor_profile_from_assignment()', 'execute'),
  'anon cannot execute the tutor profile synchronization trigger function'
);
select ok(
  not has_function_privilege('authenticated', 'public.mac_sync_tutor_profile_from_assignment()', 'execute'),
  'authenticated cannot execute the tutor profile synchronization trigger function'
);

insert into public.organizations (id, name, slug)
values
  ('91000000-0000-4000-8000-000000000001', 'Tutor Workspace Test', 'tutor-workspace-test'),
  ('91000000-0000-4000-8000-000000000002', 'Tutor Workspace Alternate', 'tutor-workspace-alternate');
insert into public.sites (id, organization_id, name, code)
values (
  '92000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  'Tutor Test Site',
  'tutor-test-site'
);
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '93000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'tutor-workspace@example.test', '',
  now(), '{}', '{}', now(), now()
);
insert into public.people (id, first_name, last_name, primary_email)
values (
  '94000000-0000-4000-8000-000000000001',
  'Tutor',
  'Workspace',
  'tutor-workspace@example.test'
);
insert into public.users (id, person_id, account_status)
values (
  '93000000-0000-4000-8000-000000000001',
  '94000000-0000-4000-8000-000000000001',
  'active'
);
insert into public.profiles (
  id, user_id, full_name, email, organization_id, site_id, person_id,
  enterprise_user_id
) values (
  '95000000-0000-4000-8000-000000000001',
  '93000000-0000-4000-8000-000000000001',
  'Tutor Workspace',
  'tutor-workspace@example.test',
  '91000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000001',
  '94000000-0000-4000-8000-000000000001',
  '93000000-0000-4000-8000-000000000001'
);
insert into public.role_assignments (
  id, user_id, role_key, organization_id, site_id, status
) values (
  '96000000-0000-4000-8000-000000000001',
  '93000000-0000-4000-8000-000000000001',
  'tutor',
  '91000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000001',
  'active'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"93000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
select is(
  (select name from public.organizations where id = '91000000-0000-4000-8000-000000000001'),
  'Tutor Workspace Test',
  'a Tutor can read the assigned organization name'
);
select is(
  (select name from public.sites where id = '92000000-0000-4000-8000-000000000001'),
  'Tutor Test Site',
  'a Tutor can read the assigned site name'
);
reset role;

select ok(
  exists (
    select 1
    from public.tutor_profiles
    where user_id = '95000000-0000-4000-8000-000000000001'
      and organization_id = '91000000-0000-4000-8000-000000000001'
      and site_id = '92000000-0000-4000-8000-000000000001'
      and person_id = '94000000-0000-4000-8000-000000000001'
  ),
  'an active Tutor assignment creates its linked tutor profile'
);

update public.role_assignments
set site_id = null
where user_id = '93000000-0000-4000-8000-000000000001'
  and role_key = 'tutor';

select ok(
  exists (
    select 1
    from public.tutor_profiles
    where user_id = '95000000-0000-4000-8000-000000000001'
      and site_id is null
  ),
  'Tutor assignment scope changes synchronize the linked tutor profile'
);

insert into public.staff (id, organization_id, person_id, staff_type)
values (
  '97000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  '94000000-0000-4000-8000-000000000001',
  'tutor'
);

update public.tutor_profiles
set staff_id = '97000000-0000-4000-8000-000000000001'
where user_id = '95000000-0000-4000-8000-000000000001';

insert into public.role_assignments (
  id, user_id, role_key, organization_id, site_id, status
) values (
  '96000000-0000-4000-8000-000000000002',
  '93000000-0000-4000-8000-000000000001',
  'tutor',
  '91000000-0000-4000-8000-000000000002',
  null,
  'active'
);

select ok(
  exists (
    select 1
    from public.tutor_profiles
    where user_id = '95000000-0000-4000-8000-000000000001'
      and organization_id = '91000000-0000-4000-8000-000000000002'
      and staff_id is null
  ),
  'changing the selected Tutor organization clears an incompatible staff link'
);

update public.role_assignments
set status = 'revoked'
where id = '96000000-0000-4000-8000-000000000002';

select ok(
  exists (
    select 1
    from public.tutor_profiles
    where user_id = '95000000-0000-4000-8000-000000000001'
      and organization_id = '91000000-0000-4000-8000-000000000001'
      and site_id is null
  ),
  'revoking the selected Tutor assignment falls back to another effective assignment'
);

select * from finish();
rollback;
