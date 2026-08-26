begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(22);

insert into auth.users (id, email)
values
  ('11000000-0000-4000-8000-000000000001', 'tenant-org-admin@example.test'),
  ('11000000-0000-4000-8000-000000000002', 'tenant-site-admin@example.test'),
  ('11000000-0000-4000-8000-000000000003', 'tenant-expired@example.test'),
  ('11000000-0000-4000-8000-000000000004', 'tenant-platform@example.test');

insert into public.users (id, account_status)
values
  ('11000000-0000-4000-8000-000000000001', 'active'),
  ('11000000-0000-4000-8000-000000000002', 'active'),
  ('11000000-0000-4000-8000-000000000003', 'active'),
  ('11000000-0000-4000-8000-000000000004', 'active');

insert into public.organizations (id, name, slug)
values
  ('21000000-0000-4000-8000-000000000001', 'Tenant A', 'tenant-context-a'),
  ('21000000-0000-4000-8000-000000000002', 'Tenant B', 'tenant-context-b');

insert into public.sites (id, organization_id, name, code)
values
  (
    '31000000-0000-4000-8000-000000000001',
    '21000000-0000-4000-8000-000000000001',
    'Tenant A Site One',
    'A1'
  ),
  (
    '31000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000001',
    'Tenant A Site Two',
    'A2'
  ),
  (
    '31000000-0000-4000-8000-000000000003',
    '21000000-0000-4000-8000-000000000002',
    'Tenant B Site',
    'B1'
  );

insert into public.role_assignments (
  id,
  organization_id,
  user_id,
  site_id,
  role_key,
  status,
  valid_until
) values
  (
    '41000000-0000-4000-8000-000000000001',
    '21000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000001',
    null,
    'organization_admin',
    'active',
    null
  ),
  (
    '41000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000002',
    '31000000-0000-4000-8000-000000000001',
    'site_admin',
    'active',
    null
  ),
  (
    '41000000-0000-4000-8000-000000000003',
    '21000000-0000-4000-8000-000000000001',
    '11000000-0000-4000-8000-000000000003',
    '31000000-0000-4000-8000-000000000001',
    'teacher',
    'active',
    now() - interval '1 day'
  ),
  (
    '41000000-0000-4000-8000-000000000004',
    null,
    '11000000-0000-4000-8000-000000000004',
    null,
    'platform_admin',
    'active',
    null
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

select ok(
  public.mac_can_access_organization('21000000-0000-4000-8000-000000000001'),
  'organization admin can enter their tenant context'
);

select ok(
  not public.mac_can_access_organization('21000000-0000-4000-8000-000000000002'),
  'organization admin cannot enter another tenant context'
);

select ok(
  public.mac_can_access_site(
    '21000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000002'
  ),
  'organization-scoped access includes sites in the same tenant'
);

select ok(
  not public.mac_can_access_site(
    '21000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000003'
  ),
  'a site cannot be paired with the wrong organization context'
);

select ok(
  not public.mac_is_site_admin(
    '21000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000003'
  ),
  'organization admin authorization rejects a foreign-tenant site ID'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

select ok(
  public.mac_can_access_site(
    '21000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000001'
  ),
  'site admin can enter their assigned site context'
);

select ok(
  not public.mac_can_access_site(
    '21000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000002'
  ),
  'site admin cannot enter a sibling site context'
);

select ok(
  public.mac_can_access_organization('21000000-0000-4000-8000-000000000001'),
  'site-scoped access includes its owning organization context'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

select ok(
  not public.mac_can_access_site(
    '21000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000001'
  ),
  'elapsed assignments do not grant tenant context'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000004","role":"authenticated"}',
  true
);

select ok(
  public.mac_can_access_organization('21000000-0000-4000-8000-000000000002'),
  'platform admin can enter an existing organization context'
);

select ok(
  public.mac_can_access_site(
    '21000000-0000-4000-8000-000000000002',
    '31000000-0000-4000-8000-000000000003'
  ),
  'platform admin can enter an existing site context'
);

select ok(
  not public.mac_can_access_organization('21000000-0000-4000-8000-000000000099'),
  'platform admin cannot enter a nonexistent tenant context'
);

reset role;

select throws_ok(
  $$
    insert into public.role_assignments (
      organization_id, user_id, site_id, role_key
    ) values (
      '21000000-0000-4000-8000-000000000001',
      '11000000-0000-4000-8000-000000000002',
      '31000000-0000-4000-8000-000000000003',
      'site_admin'
    )
  $$,
  '23503',
  null,
  'role assignments reject a site from another tenant'
);

insert into public.people (id, first_name, last_name)
values
  ('51000000-0000-4000-8000-000000000001', 'Tenant', 'Staff'),
  ('51000000-0000-4000-8000-000000000002', 'Tenant', 'Guardian');

select throws_ok(
  $$
    insert into public.staff (
      organization_id, person_id, primary_site_id
    ) values (
      '21000000-0000-4000-8000-000000000001',
      '51000000-0000-4000-8000-000000000001',
      '31000000-0000-4000-8000-000000000003'
    )
  $$,
  '23503',
  null,
  'staff reject a primary site from another tenant'
);

insert into public.profiles (
  id, user_id, full_name, email, organization_id
) values (
  '61000000-0000-4000-8000-000000000001',
  '11000000-0000-4000-8000-000000000001',
  'Tenant Parent',
  'tenant-org-admin@example.test',
  '21000000-0000-4000-8000-000000000001'
);

select throws_ok(
  $$
    update public.profiles
    set site_id = '31000000-0000-4000-8000-000000000003'
    where id = '61000000-0000-4000-8000-000000000001'
  $$,
  '23503',
  null,
  'profiles reject a site from another tenant'
);

select throws_ok(
  $$
    update public.profiles
    set organization_id = null,
        site_id = '31000000-0000-4000-8000-000000000001'
    where id = '61000000-0000-4000-8000-000000000001'
  $$,
  '23514',
  null,
  'profiles cannot retain a site without an organization context'
);

insert into public.students (
  id, parent_id, first_name, last_name, grade_level, organization_id
) values (
  '71000000-0000-4000-8000-000000000001',
  '61000000-0000-4000-8000-000000000001',
  'Tenant',
  'Student',
  '5',
  '21000000-0000-4000-8000-000000000001'
);

select throws_ok(
  $$
    update public.students
    set primary_site_id = '31000000-0000-4000-8000-000000000003'
    where id = '71000000-0000-4000-8000-000000000001'
  $$,
  '23503',
  null,
  'students reject a primary site from another tenant'
);

select throws_ok(
  $$
    update public.students
    set organization_id = null,
        primary_site_id = '31000000-0000-4000-8000-000000000001'
    where id = '71000000-0000-4000-8000-000000000001'
  $$,
  '23514',
  null,
  'students cannot retain a site without an organization context'
);

insert into auth.users (id, email)
values (
  '11000000-0000-4000-8000-000000000005',
  'tenant-tutor@example.test'
);

insert into public.profiles (
  id, user_id, full_name, email, organization_id
) values (
  '61000000-0000-4000-8000-000000000002',
  '11000000-0000-4000-8000-000000000005',
  'Tenant Tutor',
  'tenant-tutor@example.test',
  '21000000-0000-4000-8000-000000000001'
);

insert into public.tutor_profiles (
  id, user_id, organization_id
) values (
  '72000000-0000-4000-8000-000000000001',
  '61000000-0000-4000-8000-000000000002',
  '21000000-0000-4000-8000-000000000001'
);

insert into public.staff (
  id, organization_id, person_id
) values (
  '52000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000001',
  '51000000-0000-4000-8000-000000000001'
);

select throws_ok(
  $$
    update public.tutor_profiles
    set organization_id = null,
        site_id = '31000000-0000-4000-8000-000000000001'
    where id = '72000000-0000-4000-8000-000000000001'
  $$,
  '23514',
  null,
  'tutors cannot retain a site without an organization context'
);

select throws_ok(
  $$
    update public.tutor_profiles
    set organization_id = null,
        site_id = null,
        staff_id = '52000000-0000-4000-8000-000000000001'
    where id = '72000000-0000-4000-8000-000000000001'
  $$,
  '23514',
  null,
  'tutors cannot retain linked staff without an organization context'
);

insert into public.guardians (
  id, organization_id, person_id
) values (
  '81000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000002',
  '51000000-0000-4000-8000-000000000002'
);

select throws_ok(
  $$
    insert into public.guardian_student_relationships (
      organization_id, guardian_id, student_id, relationship_type
    ) values (
      '21000000-0000-4000-8000-000000000001',
      '81000000-0000-4000-8000-000000000001',
      '71000000-0000-4000-8000-000000000001',
      'guardian'
    )
  $$,
  '23503',
  null,
  'guardian relationships reject a guardian from another tenant'
);

select lives_ok(
  $$
    update public.students
    set primary_site_id = '31000000-0000-4000-8000-000000000001'
    where id = '71000000-0000-4000-8000-000000000001'
  $$,
  'tenant-owned records accept a site in the same organization'
);

select * from finish();
rollback;
