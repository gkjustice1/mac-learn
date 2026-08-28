begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(10);

insert into auth.users (id,email) values
('15000000-0000-4000-8000-000000000001','assigned-tutor@example.test'),
('15000000-0000-4000-8000-000000000002','other-tutor@example.test');
insert into public.organizations (id,name,slug) values
('25000000-0000-4000-8000-000000000001','Tutor Access Test Organization','tutor-access-test');
insert into public.users (id,account_status) values
('15000000-0000-4000-8000-000000000001','active'),
('15000000-0000-4000-8000-000000000002','active');
insert into public.profiles (id,user_id,full_name,email,organization_id) values
('65000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000001','Assigned Tutor','assigned-tutor@example.test','25000000-0000-4000-8000-000000000001'),
('65000000-0000-4000-8000-000000000002','15000000-0000-4000-8000-000000000002','Other Tutor','other-tutor@example.test','25000000-0000-4000-8000-000000000001');
insert into public.tutor_profiles (id,user_id,organization_id) values
('55000000-0000-4000-8000-000000000001','65000000-0000-4000-8000-000000000001','25000000-0000-4000-8000-000000000001'),
('55000000-0000-4000-8000-000000000002','65000000-0000-4000-8000-000000000002','25000000-0000-4000-8000-000000000001');
insert into public.role_assignments (organization_id,user_id,role_key,status) values
('25000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000001','tutor','active'),
('25000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','tutor','active');
insert into public.students (id,parent_id,first_name,last_name,grade_level,organization_id) values
('75000000-0000-4000-8000-000000000001','65000000-0000-4000-8000-000000000001','Assigned','Student','5','25000000-0000-4000-8000-000000000001'),
('75000000-0000-4000-8000-000000000002','65000000-0000-4000-8000-000000000002','Unassigned','Student','5','25000000-0000-4000-8000-000000000001');
insert into public.sessions (id,student_id,parent_id,tutor_id,start_time,end_time) values
('85000000-0000-4000-8000-000000000001','75000000-0000-4000-8000-000000000001','65000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001',now(),now()+interval '1 hour'),
('85000000-0000-4000-8000-000000000002','75000000-0000-4000-8000-000000000002','65000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000002',now(),now()+interval '1 hour');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.tutor_profiles),1::bigint,'a tutor can view only their own tutor profile');
select is((select count(*) from public.sessions),1::bigint,'a tutor can view only assigned sessions');
select is((select count(*) from public.students),1::bigint,'a tutor can view only assigned students');
select is((select count(*) from public.students where id='75000000-0000-4000-8000-000000000002'),0::bigint,'an unassigned student is hidden from the tutor');
select throws_ok($$insert into public.session_notes (session_id,tutor_id,skills_covered) values ('85000000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000001','attempt')$$,'42501','new row violates row-level security policy for table "session_notes"','a tutor cannot write notes for another tutor session');
select lives_ok($$insert into public.session_notes (session_id,tutor_id,skills_covered) values ('85000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001','covered')$$,'a tutor can write notes for an assigned session');
select throws_ok($$insert into public.progress_reports (student_id,tutor_id,reporting_period) values ('75000000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000001','Fall')$$,'42501','new row violates row-level security policy for table "progress_reports"','a tutor cannot create a progress report for an unassigned student');
select lives_ok($$insert into public.progress_reports (student_id,tutor_id,reporting_period) values ('75000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001','Fall')$$,'a tutor can create a progress report for an assigned student');
update public.students set grade_level='12' where id='75000000-0000-4000-8000-000000000001';
select is((select grade_level from public.students where id='75000000-0000-4000-8000-000000000001'),'5','a tutor cannot alter an assigned student');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{}',true);
select ok(not public.mac_tutor_is_assigned_to_student('75000000-0000-4000-8000-000000000001'),'unauthenticated callers cannot resolve tutor assignments');
reset role;
select * from finish();
rollback;
