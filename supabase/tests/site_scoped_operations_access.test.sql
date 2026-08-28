begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(9);

insert into auth.users (id, email) values
  ('18000000-0000-4000-8000-000000000001', 'site-admin@example.test'),
  ('18000000-0000-4000-8000-000000000002', 'other-site-admin@example.test'),
  ('18000000-0000-4000-8000-000000000003', 'organization-admin@example.test');
insert into public.organizations (id, name, slug) values
  ('28000000-0000-4000-8000-000000000001', 'Site Operations Test Organization', 'site-operations-test');
insert into public.sites (id, organization_id, name, code) values
  ('38000000-0000-4000-8000-000000000001', '28000000-0000-4000-8000-000000000001', 'North Site', 'NORTH'),
  ('38000000-0000-4000-8000-000000000002', '28000000-0000-4000-8000-000000000001', 'South Site', 'SOUTH');
insert into public.users (id, account_status) values
  ('18000000-0000-4000-8000-000000000001', 'active'),
  ('18000000-0000-4000-8000-000000000002', 'active'),
  ('18000000-0000-4000-8000-000000000003', 'active');
insert into public.profiles (id, user_id, full_name, email, organization_id) values
  ('68000000-0000-4000-8000-000000000001', '18000000-0000-4000-8000-000000000001', 'North Site Admin', 'site-admin@example.test', '28000000-0000-4000-8000-000000000001'),
  ('68000000-0000-4000-8000-000000000002', '18000000-0000-4000-8000-000000000002', 'South Site Admin', 'other-site-admin@example.test', '28000000-0000-4000-8000-000000000001'),
  ('68000000-0000-4000-8000-000000000003', '18000000-0000-4000-8000-000000000003', 'Organization Admin', 'organization-admin@example.test', '28000000-0000-4000-8000-000000000001');
insert into public.role_assignments (organization_id, site_id, user_id, role_key, status) values
  ('28000000-0000-4000-8000-000000000001', '38000000-0000-4000-8000-000000000001', '18000000-0000-4000-8000-000000000001', 'site_admin', 'active'),
  ('28000000-0000-4000-8000-000000000001', '38000000-0000-4000-8000-000000000002', '18000000-0000-4000-8000-000000000002', 'site_admin', 'active'),
  ('28000000-0000-4000-8000-000000000001', null, '18000000-0000-4000-8000-000000000003', 'organization_admin', 'active');
insert into public.students (id, parent_id, first_name, last_name, grade_level, organization_id) values
  ('78000000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', 'North', 'Student', '5', '28000000-0000-4000-8000-000000000001'),
  ('78000000-0000-4000-8000-000000000002', '68000000-0000-4000-8000-000000000002', 'South', 'Student', '5', '28000000-0000-4000-8000-000000000001');
insert into public.classrooms (id, organization_id, site_id, name, code) values
  ('88000000-0000-4000-8000-000000000001', '28000000-0000-4000-8000-000000000001', '38000000-0000-4000-8000-000000000001', 'North Classroom', 'NORTH-1'),
  ('88000000-0000-4000-8000-000000000002', '28000000-0000-4000-8000-000000000001', '38000000-0000-4000-8000-000000000002', 'South Classroom', 'SOUTH-1');
insert into public.classroom_student_enrollments (organization_id, classroom_id, student_id) values
  ('28000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-000000000001', '78000000-0000-4000-8000-000000000001'),
  ('28000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-000000000002', '78000000-0000-4000-8000-000000000002');
insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values
  ('28000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-000000000001', '78000000-0000-4000-8000-000000000001', '18000000-0000-4000-8000-000000000001', 'observation', 'North record'),
  ('28000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-000000000002', '78000000-0000-4000-8000-000000000002', '18000000-0000-4000-8000-000000000002', 'observation', 'South record');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*) from public.classrooms), 1::bigint, 'a site admin views only their site classrooms');
select is((select count(*) from public.classroom_student_enrollments), 1::bigint, 'a site admin views only their site enrollments');
select is((select count(*) from public.educator_instructional_records), 1::bigint, 'a site admin views only their site instructional records');
select lives_ok($$update public.classrooms set name = 'Updated North Classroom' where id = '88000000-0000-4000-8000-000000000001'$$, 'a site admin manages their site classroom');
select is((select count(*) from public.classrooms where id = '88000000-0000-4000-8000-000000000002'), 0::bigint, 'another site classroom is hidden');
select throws_ok($$insert into public.classroom_student_enrollments (organization_id, classroom_id, student_id) values ('28000000-0000-4000-8000-000000000001', '88000000-0000-4000-8000-000000000002', '78000000-0000-4000-8000-000000000002')$$, '42501', 'new row violates row-level security policy for table "classroom_student_enrollments"', 'a site admin cannot manage another site enrollment');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*) from public.classrooms), 2::bigint, 'an organization admin retains organization-wide classroom access');
select is((select count(*) from public.classroom_student_enrollments), 2::bigint, 'an organization admin retains organization-wide enrollment access');
select is((select count(*) from public.educator_instructional_records), 2::bigint, 'an organization admin retains organization-wide instructional record access');
reset role;
select * from finish();
rollback;
