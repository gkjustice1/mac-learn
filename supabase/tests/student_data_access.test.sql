begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(20);

insert into auth.users (id, email) values
  ('17000000-0000-4000-8000-000000000001', 'assigned-student@example.test'),
  ('17000000-0000-4000-8000-000000000002', 'other-student@example.test');
insert into public.organizations (id, name, slug) values
  ('27000000-0000-4000-8000-000000000001', 'Student Access Test Organization', 'student-access-test'),
  ('27000000-0000-4000-8000-000000000002', 'Second Student Access Organization', 'student-access-test-two');
insert into public.sites (id, organization_id, name, code) values
  ('37000000-0000-4000-8000-000000000001', '27000000-0000-4000-8000-000000000001', 'Student Access Site', 'STUDENT'),
  ('37000000-0000-4000-8000-000000000002', '27000000-0000-4000-8000-000000000002', 'Second Student Access Site', 'STUDENT-2');
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
  ('27000000-0000-4000-8000-000000000002', '17000000-0000-4000-8000-000000000001', 'student', 'active'),
  ('27000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000002', 'student', 'active');
insert into public.students (id, parent_id, first_name, last_name, grade_level, organization_id, primary_site_id, person_id) values
  ('77000000-0000-4000-8000-000000000001', '67000000-0000-4000-8000-000000000001', 'Assigned', 'Student', '5', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', '47000000-0000-4000-8000-000000000001'),
  ('77000000-0000-4000-8000-000000000003', '67000000-0000-4000-8000-000000000001', 'Assigned', 'Student', '5', '27000000-0000-4000-8000-000000000002', '37000000-0000-4000-8000-000000000002', '47000000-0000-4000-8000-000000000001'),
  ('77000000-0000-4000-8000-000000000002', '67000000-0000-4000-8000-000000000002', 'Other', 'Student', '5', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', '47000000-0000-4000-8000-000000000002');
insert into public.classrooms (id, organization_id, site_id, name, code) values
  ('87000000-0000-4000-8000-000000000001', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', 'Assigned Student Classroom', 'STUDENT-1'),
  ('87000000-0000-4000-8000-000000000003', '27000000-0000-4000-8000-000000000002', '37000000-0000-4000-8000-000000000002', 'Second Assigned Student Classroom', 'STUDENT-3'),
  ('87000000-0000-4000-8000-000000000002', '27000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', 'Other Student Classroom', 'STUDENT-2');
insert into public.classroom_student_enrollments (organization_id, classroom_id, student_id) values
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-000000000001'),
  ('27000000-0000-4000-8000-000000000002', '87000000-0000-4000-8000-000000000003', '77000000-0000-4000-8000-000000000003'),
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000002', '77000000-0000-4000-8000-000000000002');
insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000001', 'observation', 'Assigned record'),
  ('27000000-0000-4000-8000-000000000002', '87000000-0000-4000-8000-000000000003', '77000000-0000-4000-8000-000000000003', '17000000-0000-4000-8000-000000000001', 'observation', 'Second assigned record'),
  ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000002', '77000000-0000-4000-8000-000000000002', '17000000-0000-4000-8000-000000000002', 'observation', 'Other record');
insert into public.subjects (id, name, grade_band) values
  ('97000000-0000-4000-8000-000000000001', 'Student Reading', '3-5');
insert into public.tutor_profiles (id, user_id, approval_status) values
  ('57000000-0000-4000-8000-000000000001', '67000000-0000-4000-8000-000000000002', 'approved');
insert into public.sessions (id, student_id, tutor_id, subject_id, start_time, end_time) values
  ('95000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-000000000001', '57000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000001', now() - interval '2 hours', now() - interval '1 hour'),
  ('95000000-0000-4000-8000-000000000002', '77000000-0000-4000-8000-000000000002', '57000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000001', now() + interval '1 day', now() + interval '1 day 1 hour'),
  ('95000000-0000-4000-8000-000000000003', '77000000-0000-4000-8000-000000000003', '57000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000001', now() + interval '2 days', now() + interval '2 days 1 hour');
insert into public.homework_uploads (student_id, session_id, subject_id, file_url, file_name, notes) values
  ('77000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000001', 'https://example.test/own.pdf', 'Own assignment', 'Own instructions'),
  ('77000000-0000-4000-8000-000000000002', '95000000-0000-4000-8000-000000000002', '97000000-0000-4000-8000-000000000001', 'https://example.test/other.pdf', 'Other assignment', 'Hidden instructions');
insert into public.session_notes (session_id, tutor_id, attendance_status, skills_covered, performance_notes, homework_assigned, parent_summary, internal_notes) values
  ('95000000-0000-4000-8000-000000000001', '57000000-0000-4000-8000-000000000001', 'present', 'Own skill', 'Own feedback', 'Own homework', 'Guardian summary', 'Tutor private note'),
  ('95000000-0000-4000-8000-000000000002', '57000000-0000-4000-8000-000000000001', 'present', 'Other skill', 'Other feedback', 'Other homework', 'Other guardian summary', 'Other private note');
insert into public.progress_reports (student_id, tutor_id, subject_id, reporting_period, strengths, next_goals) values
  ('77000000-0000-4000-8000-000000000001', '57000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000001', 'Own period', 'Own strengths', 'Own goals'),
  ('77000000-0000-4000-8000-000000000002', '57000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000001', 'Other period', 'Other strengths', 'Other goals');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select array_agg(student_id order by student_id) from public.mac_current_student_ids() as eligible(student_id)), array['77000000-0000-4000-8000-000000000001'::uuid, '77000000-0000-4000-8000-000000000003'::uuid], 'a student resolves every eligible enterprise student record');
select is((select count(*) from public.students), 2::bigint, 'a student can view only their own student records');
select is((select count(*) from public.classroom_student_enrollments), 2::bigint, 'a student can view only their own active enrollments');
select is((select count(*) from public.classrooms), 2::bigint, 'a student can view only their enrolled classrooms');
select is((select count(*) from public.educator_instructional_records), 2::bigint, 'a student can view only their own instructional records');
select is((select count(*) from public.classroom_student_enrollments where student_id = '77000000-0000-4000-8000-000000000002'), 0::bigint, 'another student enrollment is hidden');
select is((select count(*) from public.educator_instructional_records where student_id = '77000000-0000-4000-8000-000000000002'), 0::bigint, 'another student instructional record is hidden');
select is((select count(*) from public.sessions), 2::bigint, 'a student sees sessions only for canonical enrollments in active role scopes');
select is((select count(*) from public.sessions where student_id = '77000000-0000-4000-8000-000000000002'), 0::bigint, 'a same-tenant student session is hidden');
select is((select count(*) from public.homework_uploads), 1::bigint, 'a student sees only their own assignments');
select is((select count(*) from public.progress_reports), 1::bigint, 'a student sees only their own progress');
select is((select count(*) from public.mac_student_feedback()), 1::bigint, 'student feedback is restricted to the canonical student');
select is((select performance_notes from public.mac_student_feedback()), 'Own feedback'::text, 'student-facing feedback is returned');
select is((select count(*) from public.mac_student_feedback() where skills_covered = 'Other skill'), 0::bigint, 'another student feedback is hidden');
select ok(not has_function_privilege('anon', 'public.mac_student_feedback()', 'execute'), 'anonymous users cannot execute the Student feedback function');
select throws_ok($$insert into public.educator_instructional_records (organization_id, classroom_id, student_id, educator_user_id, record_type, content) values ('27000000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000001', '77000000-0000-4000-8000-000000000001', '17000000-0000-4000-8000-000000000001', 'instruction', 'Student write attempt')$$, '42501', 'new row violates row-level security policy for table "educator_instructional_records"', 'a student cannot create instructional records');
reset role;
update public.classroom_student_enrollments
set status = 'withdrawn'
where student_id = '77000000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*) from public.educator_instructional_records), 1::bigint, 'a withdrawn enrollment hides its instructional records');
reset role;
update public.users set account_status = 'disabled' where id = '17000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*) from public.mac_current_student_ids()), 0::bigint, 'a disabled student cannot resolve a student record');
select is((select count(*) from public.students), 0::bigint, 'a disabled student cannot view student data');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{}', true);
select is((select count(*) from public.mac_current_student_ids()), 0::bigint, 'an unauthenticated caller cannot resolve a student record');
reset role;
select * from finish();
rollback;
