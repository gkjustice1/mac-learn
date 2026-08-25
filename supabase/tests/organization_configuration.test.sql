begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(18);

insert into auth.users (id, email)
values
  ('40000000-0000-4000-8000-000000000001', 'configuration-admin@example.test'),
  ('40000000-0000-4000-8000-000000000002', 'configuration-org-admin@example.test'),
  ('40000000-0000-4000-8000-000000000003', 'configuration-user@example.test');

insert into public.users (id, account_status)
select id, 'active'
from auth.users
where id in (
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003'
);

insert into public.organizations (id, name, slug)
values ('50000000-0000-4000-8000-000000000001', 'Configuration Test Organization', 'configuration-test-organization');

select is(
  (select default_timezone from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  'America/New_York',
  'creating an organization seeds the default timezone'
);

select is(
  (select default_locale from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  'en-US',
  'creating an organization seeds the default locale'
);

select is(
  (select supported_locales from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  array['en-US', 'es-US', 'ht-HT']::text[],
  'creating an organization seeds the supported MAC Learn locales'
);

insert into public.role_assignments (user_id, role_key, status)
values ('40000000-0000-4000-8000-000000000001', 'platform_admin', 'active');

insert into public.role_assignments (user_id, role_key, organization_id, status)
values ('40000000-0000-4000-8000-000000000002', 'organization_admin', '50000000-0000-4000-8000-000000000001', 'active');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select lives_ok(
  'insert into public.organizations (id, name, slug)
   values (
     ''50000000-0000-4000-8000-000000000002'',
     ''Authenticated Configuration Test Organization'',
     ''authenticated-configuration-test-organization''
   )',
  'a platform admin can create an organization when configuration inserts are restricted'
);

select is(
  (select default_timezone from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000002'),
  'America/New_York',
  'an authenticated platform-admin organization creation seeds its configuration'
);

select is(
  (select count(*) from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  1::bigint,
  'a platform admin can read organization configuration'
);

select ok(
  not has_table_privilege(
    current_user,
    'public.organization_configurations',
    'UPDATE'
  ),
  'authenticated users do not have direct UPDATE privilege on organization configuration'
);

select throws_ok(
  'update public.organization_configurations
      set default_locale = ''abcd'',
          supported_locales = array[''abcd'']::text[]
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '42501',
  'permission denied for table organization_configurations',
  'a platform-admin direct Data API update is rejected before locale values reach the database'
);

select is(
  (select default_locale from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  'en-US',
  'the locale remains unchanged after a denied direct update'
);

select ok(
  not has_table_privilege(
    current_user,
    'public.organization_configurations',
    'DELETE'
  ),
  'a platform admin does not have DELETE privilege on organization configuration'
);

select throws_ok(
  'delete from public.organization_configurations
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '42501',
  'permission denied for table organization_configurations',
  'a platform-admin delete attempt is rejected by table privileges'
);

select is(
  (select count(*) from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  1::bigint,
  'the seeded organization configuration remains after a denied delete'
);

set local role service_role;

select lives_ok(
  'update public.organization_configurations
      set default_timezone = ''America/Chicago'',
          default_locale = ''es-419'',
          supported_locales = array[''en-US'', ''es-419'']::text[],
          academic_year_start_month = 7
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  'the server-only administrative role can update organization configuration'
);

select is(
  (select default_locale from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  'es-419',
  'the server-only administrative update persists'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"40000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

select is(
  (select count(*) from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  1::bigint,
  'an organization admin can read its organization configuration'
);

select throws_ok(
  'update public.organization_configurations
      set default_timezone = ''America/Denver''
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '42501',
  'permission denied for table organization_configurations',
  'an organization-admin direct Data API update is rejected by table privileges'
);

select is(
  (select default_timezone from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  'America/Chicago',
  'the organization configuration remains unchanged after a denied organization-admin update'
);

select set_config('request.jwt.claims', '{"sub":"40000000-0000-4000-8000-000000000003","role":"authenticated"}', true);

select is(
  (select count(*) from public.organization_configurations),
  0::bigint,
  'a user without tenant administration cannot read organization configuration'
);

select * from finish();
rollback;
