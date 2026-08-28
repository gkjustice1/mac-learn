begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(14);

insert into auth.users (id, email) values
  ('16000000-0000-4000-8000-000000000001', 'assigned-educator@example.test'),
  ('16000000-0000-4000-8000-000000000002', 'other-educator@example.test'),
  ('16000000-0000-4000-8000-000000000003', 'organization-admin@example.test');
insert into public.organizations (id, name, slug) values
  ('26000000-0000-4000-8000-000000000001', 'Educator Access Test Organization', 'educator-access-test');
insert into public.sites (id, organization_id, name, code) values
  ('36000000-0000-4000-8000-000000000001', '26000000-0000-4000-8000-000000000001', 'Educator Access Site', 'EDU');
insert into public.users (id, account_status) values
  ('16000000-0000-4000-8000-000000000001', 'active'),
  ('16000000-0000-4000-8000-000000000002', 'active'),
  ('16000000-0000-4000-8000-000000000003', 'active');
insert into public.profiles (id, user_id, full_name, email, organization_id) values
  ('66000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000001', 'Assigned Educator', 'assigned-educator@example.test', '26000000-0000-4000-8000-000000000001'),
  ('66000000-0000-4000-8000-000000000002', '16000000-0000-4000-8000-000000000002', 'Other Educator', 'other-educator@example.test', '26000000-0000-4000-8000-000000000001'),
  ('66000000-0000-4000-8000-000000000003', '16000000-0000-4000-8000-000000000003', 'Organization Admin', 'organization-admin@example.test', '26000000-0000-4000-8000-000000000001');
insert into public.role_assignments (organization_id, user_id, role_key, status) values
  ('26000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000001', 'teacher', 'active'),
  ('26000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000002', 'teacher', 'active'),
  ('26000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000003', 'organization_admin', 'active');
insert into public.students (id, parent_id, first_name, last_name, grade_level, organization_id) values
  ('76000000-0000-4000-8000-000000000001', '66000000-0000-4000-8000-000000000001', 'Assigned', 'Student', '5', '26000000-0000-4000-8000-000000000001'),
  ('76000000-0000-4000-8000-000000000002', '66000000-0000-4000-8000-000000000002', 'Other', 'Student', '5', '26000000-0000-4000-8000-000000000001');
insert into public.classrooms (id, organization_id, site_id, name, code) values
  ('86000000-0000-4000-8000-000000000001', '26000000-0000-4000-8000-000000000001', '36000000-0000-4000-8000-000000000001', 'Assigned Classroom', 'EDU-1'),
  ('86000000-0000-4000-8000-000000000002', '26000000-0000-4000-8000-000000000001', '36000000-0000-4000-8000-000000000001', 'Other Classroom', 'EDU-2');
insert into public.classroom_educators (organization_id, classroom_id, user_id) values
  ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000001'),
  ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000002', '16000000-0000-4000-8000-000000000002');
insert into public.classroom_student_enrollments (organization_id, classroom_id, student_id) values
  ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000001', '76000000-0000-4000-8000-000000000001'),
  ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000002', '76000000-0000-4000-8000-000000000002');
insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values
  ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000001', '76000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000001', 'observation', 'Assigned observation'),
  ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000002', '76000000-0000-4000-8000-000000000002', '16000000-0000-4000-8000-000000000002', 'observation', 'Other observation');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.mac_is_active_classroom_educator('86000000-0000-4000-8000-000000000001'), 'an assigned educator resolves their classroom');
select ok(not public.mac_is_active_classroom_educator('86000000-0000-4000-8000-000000000002'), 'an educator cannot resolve another educator classroom');
select is((select count(*) from public.classrooms), 1::bigint, 'an educator sees only assigned classrooms');
select is((select count(*) from public.classroom_student_enrollments), 1::bigint, 'an educator sees only enrolled students for assigned classrooms');
select is((select count(*) from public.students), 1::bigint, 'an educator sees only assigned students');
select is((select count(*) from public.educator_instructional_records), 1::bigint, 'an educator sees only records for assigned students');
select lives_ok($$insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000001', '76000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000001', 'instruction', 'Assigned instruction')$$, 'an educator can create their own record for an assigned student');
select throws_ok($$insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values ('26000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000002', '76000000-0000-4000-8000-000000000002', '16000000-0000-4000-8000-000000000001', 'instruction', 'Cross classroom instruction')$$, '42501', 'new row violates row-level security policy for table "educator_instructional_records"', 'an educator cannot create a record for another educator student');
select is((with changed as (
  update public.educator_instructional_records
  set content = 'changed'
  where educator_user_id = '16000000-0000-4000-8000-000000000002'
  returning id
) select count(*) from changed), 0::bigint, 'an educator cannot alter another educator record');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*) from public.classrooms), 2::bigint, 'an organization administrator sees classrooms in their organization');
select is((select count(*) from public.classroom_educators), 2::bigint, 'an organization administrator sees educator assignments in their organization');
select is((select count(*) from public.classroom_student_enrollments), 2::bigint, 'an organization administrator sees enrollments in their organization');
select is((select count(*) from public.educator_instructional_records), 3::bigint, 'an organization administrator sees instructional records in their organization');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{}', true);
select ok(not public.mac_is_active_classroom_educator('86000000-0000-4000-8000-000000000001'), 'unauthenticated callers cannot resolve educator assignments');
reset role;
select * from finish();
rollback;
