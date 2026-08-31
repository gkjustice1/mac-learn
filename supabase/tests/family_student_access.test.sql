begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(24);
insert into auth.users (id,email) values
('14000000-0000-4000-8000-000000000001','family-access@example.test'),
('14000000-0000-4000-8000-000000000002','legacy-parent@example.test');
insert into public.organizations (id,name,slug) values ('24000000-0000-4000-8000-000000000001','Family Access Test Organization','family-access-test');
insert into public.people (id,first_name,last_name) values
('34000000-0000-4000-8000-000000000001','Family','Guardian'),
('34000000-0000-4000-8000-000000000002','Related','Student'),
('34000000-0000-4000-8000-000000000003','Unrelated','Student'),
('34000000-0000-4000-8000-000000000004','Restricted','Student');
insert into public.users (id,person_id,account_status) values ('14000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000001','active');
insert into public.profiles (id,user_id,full_name,email,organization_id) values
('64000000-0000-4000-8000-000000000001','14000000-0000-4000-8000-000000000001','Legacy Parent','family-access@example.test','24000000-0000-4000-8000-000000000001'),
('64000000-0000-4000-8000-000000000002','14000000-0000-4000-8000-000000000002','Legacy Admin','legacy-parent@example.test','24000000-0000-4000-8000-000000000001');
update public.profiles set role='admin' where id='64000000-0000-4000-8000-000000000002';
update public.profiles set role='admin' where id='64000000-0000-4000-8000-000000000001';
insert into public.role_assignments (user_id,role_key,organization_id,site_id,status) values
('14000000-0000-4000-8000-000000000001','guardian','24000000-0000-4000-8000-000000000001',null,'active');
insert into public.guardians (id,organization_id,person_id,status) values ('44000000-0000-4000-8000-000000000001','24000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000001','active');
insert into public.students (id,parent_id,first_name,last_name,grade_level,organization_id,person_id) values
('74000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001','Related','Student','5','24000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000002'),
('74000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000001','Unrelated','Student','5','24000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000003'),
('74000000-0000-4000-8000-000000000003','64000000-0000-4000-8000-000000000001','Restricted','Student','5',null,'34000000-0000-4000-8000-000000000004');
insert into public.guardian_student_relationships (organization_id,guardian_id,student_id,relationship_type,educational_access,valid_from,valid_until) values ('24000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001','parent',true,current_date-1,current_date+1);
insert into public.tutor_profiles (id,user_id,organization_id) values
('54000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002','24000000-0000-4000-8000-000000000001');
insert into public.subjects (id,name,grade_band) values
('84000000-0000-4000-8000-000000000001','Family Reading','3-5');
insert into public.sessions (id,student_id,parent_id,tutor_id,subject_id,start_time,end_time,status) values
('94000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001',null,'54000000-0000-4000-8000-000000000001','84000000-0000-4000-8000-000000000001',now()-interval '2 hours',now()-interval '1 hour','completed'),
('94000000-0000-4000-8000-000000000002','74000000-0000-4000-8000-000000000002',null,'54000000-0000-4000-8000-000000000001','84000000-0000-4000-8000-000000000001',now()+interval '1 day',now()+interval '1 day 1 hour','pending');
insert into public.session_notes (session_id,tutor_id,attendance_status,performance_notes,parent_summary) values
('94000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000001','present','Tutor-private detail','Family-visible summary'),
('94000000-0000-4000-8000-000000000002','54000000-0000-4000-8000-000000000001','present','Unrelated private detail','Unrelated summary');
insert into public.progress_reports (student_id,tutor_id,subject_id,reporting_period,strengths,next_goals) values
('74000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000001','84000000-0000-4000-8000-000000000001','Quarter 1','Growing comprehension','Cite text evidence'),
('74000000-0000-4000-8000-000000000002','54000000-0000-4000-8000-000000000001','84000000-0000-4000-8000-000000000001','Quarter 1','Unrelated strength','Unrelated goal');
select ok(has_table_privilege('authenticated','public.students','select') and has_table_privilege('authenticated','public.guardians','select') and has_table_privilege('authenticated','public.guardian_student_relationships','select'),'authenticated users retain table SELECT privileges while RLS controls family rows');
select ok(
  has_table_privilege('authenticated','public.sessions','select')
  and has_table_privilege('authenticated','public.progress_reports','select')
  and has_function_privilege('authenticated','public.mac_family_session_summaries()','execute')
  and not has_function_privilege('anon','public.mac_family_session_summaries()','execute'),
  'the Family read model is available only to authenticated callers'
);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.guardians),1::bigint,'a guardian can view only their own guardian record');
select is((select count(*) from public.guardian_student_relationships),1::bigint,'a guardian can view only active educational relationships');
select is((select count(*) from public.students),1::bigint,'a guardian can view a student linked by an active educational relationship');
select is((select first_name from public.students where id='74000000-0000-4000-8000-000000000001'),'Related','the related student remains visible to the guardian');
select is((select count(*) from public.students where id='74000000-0000-4000-8000-000000000002'),0::bigint,'an unrelated student is hidden from the guardian');
select is((select count(*) from public.students where id='74000000-0000-4000-8000-000000000003'),0::bigint,'a null student organization uses the legacy parent profile scope');
select is((select count(*) from public.sessions),1::bigint,'a guardian sees sessions only for a canonically linked student');
select is((select count(*) from public.sessions where student_id='74000000-0000-4000-8000-000000000002'),0::bigint,'an unrelated student session is hidden');
select is((select count(*) from public.progress_reports),1::bigint,'a guardian sees progress only for a canonically linked student');
select is((select count(*) from public.progress_reports where student_id='74000000-0000-4000-8000-000000000002'),0::bigint,'an unrelated student progress report is hidden');
select is((select count(*) from public.session_notes),0::bigint,'Tutor-private session note rows remain inaccessible to guardians');
select is((select count(*) from public.mac_family_session_summaries()),1::bigint,'the parent-facing summary RPC returns only linked student records');
select is((select parent_summary from public.mac_family_session_summaries()),'Family-visible summary','the Family RPC returns the intended parent summary');
select ok(
  (select relrowsecurity from pg_class where oid='public.sessions'::regclass)
  and (select relrowsecurity from pg_class where oid='public.progress_reports'::regclass)
  and (select relrowsecurity from pg_class where oid='public.session_notes'::regclass),
  'RLS remains enabled across the Family workspace source tables'
);
reset role;
update public.role_assignments
set status = 'inactive'
where user_id = '14000000-0000-4000-8000-000000000001'
  and role_key = 'guardian';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.students),0::bigint,'revoking the guardian role immediately removes linked-student access');
reset role;
update public.role_assignments
set status = 'active'
where user_id = '14000000-0000-4000-8000-000000000001'
  and role_key = 'guardian';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$insert into public.guardian_student_relationships (organization_id,guardian_id,student_id,relationship_type) values ('24000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000002','parent')$$,'42501','new row violates row-level security policy for table "guardian_student_relationships"','a guardian cannot create a relationship through the Data API');
update public.students set grade_level='12' where id='74000000-0000-4000-8000-000000000001';
select is((select grade_level from public.students where id='74000000-0000-4000-8000-000000000001'),'5','a guardian cannot change a related student through the Data API');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*) from public.students),3::bigint,'a legacy administrator retains student access during enterprise migration');
reset role;
insert into public.people (id,first_name,last_name) values ('34000000-0000-4000-8000-000000000005','Disabled','Admin');
insert into public.users (id,person_id,account_status) values ('14000000-0000-4000-8000-000000000002','34000000-0000-4000-8000-000000000005','active');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*) from public.students),0::bigint,'an active migrated legacy administrator cannot bypass enterprise authorization');
reset role;
update public.users set account_status='disabled' where id='14000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*) from public.students),0::bigint,'a disabled migrated legacy administrator cannot bypass enterprise authorization');
reset role;
update public.users set account_status='disabled' where id='14000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.students),0::bigint,'a disabled enterprise guardian cannot regain legacy student access');
reset role;
delete from public.guardian_student_relationships where guardian_id='44000000-0000-4000-8000-000000000001';
delete from public.guardians where id='44000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.students),0::bigint,'a disabled enterprise identity without a guardian record cannot use legacy access');
reset role;
select * from finish();
rollback;
