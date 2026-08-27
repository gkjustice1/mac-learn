begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(8);

insert into auth.users (id, email)
values
  ('13000000-0000-4000-8000-000000000001', 'profile-owner@example.test'),
  ('13000000-0000-4000-8000-000000000002', 'other-user@example.test');

insert into public.profiles (id, user_id, full_name, email, phone, role)
values
  ('63000000-0000-4000-8000-000000000001', '13000000-0000-4000-8000-000000000001', 'Profile Owner', 'profile-owner@example.test', '555-0101', 'parent'),
  ('63000000-0000-4000-8000-000000000002', '13000000-0000-4000-8000-000000000002', 'Other User', 'other-user@example.test', '555-0102', 'admin');

select ok(
  has_table_privilege('authenticated', 'public.profiles', 'select'),
  'authenticated users retain SELECT access to profiles under RLS'
);

select ok(
  has_column_privilege('authenticated', 'public.profiles', 'full_name', 'update')
  and has_column_privilege('authenticated', 'public.profiles', 'phone', 'update'),
  'authenticated users can update permitted personal contact fields'
);

select ok(
  not has_column_privilege('authenticated', 'public.profiles', 'role', 'update')
  and not has_column_privilege('authenticated', 'public.profiles', 'organization_id', 'update')
  and not has_column_privilege('authenticated', 'public.profiles', 'enterprise_user_id', 'update'),
  'authenticated users cannot update authorization or tenant-link fields'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"13000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.profiles),
  1::bigint,
  'a signed-in user can view only their own profile'
);

select lives_ok(
  $$update public.profiles set full_name = 'Updated Owner' where user_id = '13000000-0000-4000-8000-000000000001'$$,
  'a signed-in user can update their own permitted profile field'
);

select is(
  (select full_name from public.profiles where user_id = '13000000-0000-4000-8000-000000000001'),
  'Updated Owner',
  'the permitted personal profile update is retained'
);

select is(
  (select count(*) from public.profiles where user_id = '13000000-0000-4000-8000-000000000002'),
  0::bigint,
  'a signed-in user cannot read another user profile'
);

select throws_ok(
  $$update public.profiles set role = 'admin' where user_id = '13000000-0000-4000-8000-000000000001'$$,
  '42501',
  'permission denied for table profiles',
  'a signed-in user cannot elevate their own legacy profile role'
);

reset role;

select * from finish();

rollback;
