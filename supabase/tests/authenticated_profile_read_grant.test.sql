begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(5);

insert into auth.users (id, email)
values
  ('17000000-0000-4000-8000-000000000001', 'profile-grant-owner@example.test'),
  ('17000000-0000-4000-8000-000000000002', 'profile-grant-other@example.test');

insert into public.profiles (id, user_id, full_name, email, role)
values
  ('67000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000001', 'Grant Owner', 'profile-grant-owner@example.test', 'parent'),
  ('67000000-0000-4000-8000-000000000002', '17000000-0000-4000-8000-000000000002', 'Other Profile', 'profile-grant-other@example.test', 'parent');

select ok(
  has_table_privilege('authenticated', 'public.profiles', 'select'),
  'authenticated users can query profiles through RLS'
);
select ok(
  not has_table_privilege('anon', 'public.profiles', 'select'),
  'anonymous users cannot query profiles'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'RLS remains enabled on profiles'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"17000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.profiles),
  1::bigint,
  'an authenticated user can see their own profile'
);
select is(
  (
    select count(*)
    from public.profiles
    where user_id = '17000000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'an authenticated user cannot see another profile'
);

reset role;
select * from finish();
rollback;
