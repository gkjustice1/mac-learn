begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(5);

insert into auth.users (id, email) values
  ('19000000-0000-4000-8000-000000000001', 'invited-user@example.test'),
  ('19000000-0000-4000-8000-000000000002', 'active-user@example.test');
insert into public.users (id, account_status) values
  ('19000000-0000-4000-8000-000000000001', 'invited'),
  ('19000000-0000-4000-8000-000000000002', 'active');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"19000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.mac_activate_invited_enterprise_user(), 'an authenticated invitee activates their own identity');
select is((select account_status from public.users where id = '19000000-0000-4000-8000-000000000001'), 'active', 'activation changes only invited status');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"19000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select ok(not public.mac_activate_invited_enterprise_user(), 'an active identity cannot be activated again');
select is((select account_status from public.users where id = '19000000-0000-4000-8000-000000000002'), 'active', 'an active identity remains active');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{}', true);
select ok(not public.mac_activate_invited_enterprise_user(), 'an unauthenticated caller cannot activate an identity');
reset role;
select * from finish();
rollback;
