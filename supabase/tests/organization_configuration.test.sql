begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(20);

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

select lives_ok(
  'update public.organization_configurations
      set default_timezone = ''America/Chicago'', academic_year_start_month = 7
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  'a platform admin can update organization configuration'
);

select is(
  (select default_timezone from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  'America/Chicago',
  'platform-admin update persists'
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

select throws_ok(
  'update public.organization_configurations
      set default_timezone = ''America/NewYork''
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '22023',
  'default_timezone must be a valid IANA timezone: America/NewYork',
  'invalid IANA timezones are rejected by the database'
);

select lives_ok(
  'update public.organization_configurations
      set default_timezone = ''America/Los_Angeles''
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  'valid IANA timezones are accepted by the database'
);

select throws_ok(
  'update public.organization_configurations
      set default_locale = ''not_a_locale''
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '22023',
  'default_locale must be a valid BCP 47 locale tag: not_a_locale',
  'invalid default locales are rejected by the database'
);

select throws_ok(
  'update public.organization_configurations
      set supported_locales = array[''en-US'', ''not_a_locale'']::text[]
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '22023',
  'supported_locales must contain only valid BCP 47 locale tags',
  'invalid supported locales are rejected by the database'
);

select throws_ok(
  'update public.organization_configurations
      set supported_locales = array[''en-US'', ''en-u-ca-gregory-u-nu-latn'']::text[]
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '22023',
  'supported_locales must contain only valid BCP 47 locale tags',
  'supported locales with repeated extension singletons are rejected by the database'
);

select lives_ok(
  'update public.organization_configurations
      set default_locale = ''en-US-u-ca-islamic-civil-co-phonebk-hc-h24-kf-upper-kn-nu-arab-tz-usnyc'',
          supported_locales = array[''en-US-u-ca-islamic-civil-co-phonebk-hc-h24-kf-upper-kn-nu-arab-tz-usnyc'']::text[]
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  'valid long BCP 47 locales are accepted by the database'
);

select throws_ok(
  'update public.organization_configurations
      set default_timezone = ''Factory''
    where organization_id = ''50000000-0000-4000-8000-000000000001''',
  '22023',
  'default_timezone must be a valid IANA timezone: Factory',
  'PostgreSQL-only timezone aliases are rejected by the database'
);

update public.organization_configurations
set default_timezone = 'America/Chicago'
where organization_id = '50000000-0000-4000-8000-000000000001';

select set_config('request.jwt.claims', '{"sub":"40000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

select is(
  (select count(*) from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  1::bigint,
  'an organization admin can read its organization configuration'
);

update public.organization_configurations
set default_timezone = 'America/Denver'
where organization_id = '50000000-0000-4000-8000-000000000001';

select is(
  (select default_timezone from public.organization_configurations where organization_id = '50000000-0000-4000-8000-000000000001'),
  'America/Chicago',
  'an organization admin cannot update organization configuration'
);

select set_config('request.jwt.claims', '{"sub":"40000000-0000-4000-8000-000000000003","role":"authenticated"}', true);

select is(
  (select count(*) from public.organization_configurations),
  0::bigint,
  'a user without tenant administration cannot read organization configuration'
);

select * from finish();
rollback;
