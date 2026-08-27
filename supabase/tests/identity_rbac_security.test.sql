begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(3);

select ok(
  not has_function_privilege('anon', 'public.current_user_role()'::regprocedure, 'execute'),
  'anonymous users cannot execute the legacy current-user role helper'
);

select ok(
  has_function_privilege('authenticated', 'public.current_user_role()'::regprocedure, 'execute'),
  'authenticated users can execute the legacy helper needed by baseline RLS policies'
);

insert into auth.users (id, email)
values ('12000000-0000-4000-8000-000000000001', 'legacy-admin@example.test');

insert into public.profiles (id, user_id, full_name, email, role)
values (
  '62000000-0000-4000-8000-000000000001',
  '12000000-0000-4000-8000-000000000001',
  'Legacy Admin',
  'legacy-admin@example.test',
  'admin'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"12000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

select is(
  public.current_user_role()::text,
  'admin',
  'the legacy role helper still resolves the signed-in user role for baseline policies'
);

reset role;

select * from finish();

rollback;
