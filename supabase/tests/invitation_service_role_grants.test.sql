begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(23);

select ok(not has_table_privilege('service_role', 'public.people', 'select'), 'service_role cannot select people');
select ok(not has_table_privilege('service_role', 'public.people', 'insert'), 'service_role cannot insert people directly');
select ok(not has_table_privilege('service_role', 'public.people', 'update'), 'service_role cannot update people');
select ok(not has_table_privilege('service_role', 'public.people', 'delete'), 'service_role cannot delete people directly');
select ok(not has_table_privilege('service_role', 'public.users', 'select'), 'service_role cannot select enterprise users');
select ok(not has_table_privilege('service_role', 'public.users', 'insert'), 'service_role cannot insert enterprise users directly');
select ok(not has_table_privilege('service_role', 'public.users', 'update'), 'service_role cannot update enterprise users');
select ok(not has_table_privilege('service_role', 'public.users', 'delete'), 'service_role cannot delete enterprise users directly');
select ok(not has_table_privilege('service_role', 'public.profiles', 'select'), 'service_role cannot select profiles');
select ok(not has_table_privilege('service_role', 'public.profiles', 'insert'), 'service_role cannot insert profiles directly');
select ok(not has_table_privilege('service_role', 'public.profiles', 'update'), 'service_role cannot update profiles');
select ok(not has_table_privilege('service_role', 'public.profiles', 'delete'), 'service_role cannot delete profiles directly');

select ok(has_function_privilege('service_role', 'public.mac_create_invited_enterprise_identity(uuid,text,text,text,uuid,uuid)', 'execute'), 'service_role can execute invitation creation');
select ok(has_function_privilege('service_role', 'public.mac_cleanup_invited_enterprise_identity(uuid,uuid)', 'execute'), 'service_role can execute invitation cleanup');
select ok(not has_function_privilege('anon', 'public.mac_create_invited_enterprise_identity(uuid,text,text,text,uuid,uuid)', 'execute'), 'anon cannot create invitation identities');
select ok(not has_function_privilege('anon', 'public.mac_cleanup_invited_enterprise_identity(uuid,uuid)', 'execute'), 'anon cannot clean up invitation identities');
select ok(not has_function_privilege('authenticated', 'public.mac_create_invited_enterprise_identity(uuid,text,text,text,uuid,uuid)', 'execute'), 'authenticated cannot create invitation identities');
select ok(not has_function_privilege('authenticated', 'public.mac_cleanup_invited_enterprise_identity(uuid,uuid)', 'execute'), 'authenticated cannot clean up invitation identities');

insert into public.organizations (id, name, slug)
values ('5a000000-0000-4000-8000-000000000001', 'Invitation Test', 'invitation-test');
insert into public.sites (id, organization_id, name, code)
values ('6a000000-0000-4000-8000-000000000001', '5a000000-0000-4000-8000-000000000001', 'Test Site', 'test-site');
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '4a000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'service-role-invite@example.test', '',
  now(), '{}', '{}', now(), now()
);

set local role service_role;
select lives_ok(
  $$select public.mac_create_invited_enterprise_identity(
    '4a000000-0000-4000-8000-000000000001', 'Invite', 'Test',
    'service-role-invite@example.test',
    '5a000000-0000-4000-8000-000000000001',
    '6a000000-0000-4000-8000-000000000001'
  )$$,
  'service_role can atomically create an invited identity'
);
reset role;

select ok(
  exists (select 1 from public.people where primary_email = 'service-role-invite@example.test')
  and exists (select 1 from public.users where id = '4a000000-0000-4000-8000-000000000001' and account_status = 'invited')
  and exists (select 1 from public.profiles where user_id = '4a000000-0000-4000-8000-000000000001'),
  'invitation creation writes all three linked identity records'
);

set local role service_role;
select is(
  public.mac_cleanup_invited_enterprise_identity(
    '4a000000-0000-4000-8000-000000000001',
    '7a000000-0000-4000-8000-000000000001'
  ),
  false,
  'cleanup rejects a mismatched person identifier'
);
select is(
  public.mac_cleanup_invited_enterprise_identity(
    '4a000000-0000-4000-8000-000000000001',
    (select id from public.people where primary_email = 'service-role-invite@example.test')
  ),
  true,
  'cleanup removes only the matching invited identity'
);
reset role;

select ok(
  not exists (select 1 from public.people where primary_email = 'service-role-invite@example.test')
  and not exists (select 1 from public.users where id = '4a000000-0000-4000-8000-000000000001')
  and not exists (select 1 from public.profiles where user_id = '4a000000-0000-4000-8000-000000000001'),
  'cleanup removes all three linked identity records'
);

select * from finish();
rollback;
