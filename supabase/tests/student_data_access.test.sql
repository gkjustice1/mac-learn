begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(11);

insert into auth.users (id, email) values
  ('17000000-0000-4000-8000-000000000001', 'assigned-student@example.test'),
  ('17000000-0000-4000-8000-000000000002', 'other-student@example.test');
insert into public.organizations (id, name, slug) values
  ('27000000-0000-4000-8000-000000000001', 'Student Access Test Organization', 'student-access-test');
insert into public.sites (id, organization_id, name, code) values
  ('37000000-0000-4000-8000-000000000001', '27000000-0000-4000-8000-000000000001', 'Student Access Site', 'STUDENT');
insert into public.people (id, first_name, last_name) values
  ('47000000-0000-4000-8000-000000000001', 'Assigned', 'Student'),
  ('47000000-0000-4000-8000-000000000002', 'Other', 'Student');
insert into public.users (id, person_id, account_status) values
  ('17000000-0000-4000-8000-000000000001', '47000000-0000-4000-8000-000000000001', 'active'),
  ('17000000-0000-4000-8000-000000000002', '47000000-0000-4000-8000-000000000002', 'active');
insert into public.profiles (id, user_id, full_name, email, organization_id) values
  ('67000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000001', 'Assigned Student', 'assigned-student@example.test', '27000000-0000-4000-8000-000000000001'),
  ('67000000-0000-4000-8000-000000000002', '17000000-0000-4000-8000-000000000002', 'Other Student', 'other-student@example.test', '27000000-0000-4000-8000-000000000001');
insert into public.role_assignments (organization_id, user_id, role_key, status) values
  ('27000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000001', 'student', 'active'),
  ('27000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000002', 'student', 'active');
insert into public.students (id, parent_id, first_name, last_name, grade_level, organization_id, primary_site_id, person_id) values
  ('77000000-0000-4000-8000-000000000001', '67000000-0000-4000-8000-000000000001', 'Assigned', 'Student', '5', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', '47000000-0000-4000-8000-000000000001'),
  ('77000000-0000-4000-8000-000000000002', '67000000-0000-4000-8000-000000000002', 'Other', 'Student', '5', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', '47000000-0000-4000-8000-000000000002');
insert into public.classrooms (id, organization_id, site_id, name, code) values
  ('87000000-0000-4000-8000-000000000001', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', 'Assigned Student Classroom', 'STUDENT-1'),
  ('87000000-0000-4000-8000-000000000002', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', 'Other Student Classroom', 'STUDENT-2');
insert into public.classroom_student_enrollments (organization_id, classroom_id, student_id) values
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-000000000001'),
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000002', '77000000-0000-4000-8000-000000000002');
insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000001', 'observation', 'Assigned record'),
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000002', '77000000-0000-4000-8000-000000000002', '17000000-0000-4000-8000-000000000002', 'observation', 'Other record');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is(public.mac_current_student_id(), '77000000-0000-4000-8000-000000000001', 'a student resolves only their own enterprise student record');
select is((select count(*) from public.students), 1::bigint, 'a student can view only their own student record');
select is((select count(*) from public.classroom_student_enrollments), 1::bigint, 'a student can view only their own active enrollment');
select is((select count(*) from public.classrooms), 1::bigint, 'a student can view only their enrolled classroom');
select is((select count(*) from public.educator_instructional_records), 1::bigint, 'a student can view only their own instructional records');
select is((select count(*) from public.classroom_student_enrollments where student_id = '77000000-0000-4000-8000-000000000002'), 0::bigint, 'another student enrollment is hidden');
select is((select count(*) from public.educator_instructional_records where student_id = '77000000-0000-4000-8000-000000000002'), 0::bigint, 'another student instructional record is hidden');
select throws_ok($$insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000001', 'instruction', 'Student write attempt')$$, '42501', 'new row violates row-level security policy for table "educator_instructional_records"', 'a student cannot create instructional records');
reset role;
update public.users set account_status = 'disabled' where id = '17000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is(public.mac_current_student_id(), null::uuid, 'a disabled student cannot resolve a student record');
select is((select count(*) from public.students), 0::bigint, 'a disabled student cannot view student data');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{}', true);
select is(public.mac_current_student_id(), null::uuid, 'an unauthenticated caller cannot resolve a student record');
reset role;
select * from finish();
rollback;
