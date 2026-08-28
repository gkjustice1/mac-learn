begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(22);

insert into auth.users (id,email) values
('15000000-0000-4000-8000-000000000001','assigned-tutor@example.test'),
('15000000-0000-4000-8000-000000000002','other-tutor@example.test'),
('15000000-0000-4000-8000-000000000004','organization-tutor-admin@example.test'),
('15000000-0000-4000-8000-000000000005','foreign-replacement@example.test');
insert into public.organizations (id,name,slug) values
('25000000-0000-4000-8000-000000000001','Tutor Access Test Organization','tutor-access-test');
insert into public.organizations (id,name,slug) values
('25000000-0000-4000-8000-000000000002','Foreign Tutor Access Organization','foreign-tutor-access-test');
insert into public.sites (id,organization_id,name,code) values
('35000000-0000-4000-8000-000000000001','25000000-0000-4000-8000-000000000001','Tutor Access Site','TUTOR');
insert into public.users (id,account_status) values
('15000000-0000-4000-8000-000000000001','active'),
('15000000-0000-4000-8000-000000000002','active'),
('15000000-0000-4000-8000-000000000004','active');
insert into public.profiles (id,user_id,full_name,email,organization_id) values
('65000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000001','Assigned Tutor','assigned-tutor@example.test','25000000-0000-4000-8000-000000000001'),
('65000000-0000-4000-8000-000000000002','15000000-0000-4000-8000-000000000002','Other Tutor','other-tutor@example.test','25000000-0000-4000-8000-000000000001'),
('65000000-0000-4000-8000-000000000004','15000000-0000-4000-8000-000000000004','Organization Tutor Admin','organization-tutor-admin@example.test','25000000-0000-4000-8000-000000000001');
insert into public.tutor_profiles (id,user_id,organization_id) values
('55000000-0000-4000-8000-000000000001','65000000-0000-4000-8000-000000000001','25000000-0000-4000-8000-000000000001'),
('55000000-0000-4000-8000-000000000002','65000000-0000-4000-8000-000000000002','25000000-0000-4000-8000-000000000001');
update public.tutor_profiles set site_id='35000000-0000-4000-8000-000000000001' where id='55000000-0000-4000-8000-000000000001';
insert into public.role_assignments (organization_id,user_id,role_key,status) values
('25000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000001','tutor','active'),
('25000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','tutor','active'),
('25000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000004','organization_admin','active');
insert into public.students (id,parent_id,first_name,last_name,grade_level,organization_id) values
('75000000-0000-4000-8000-000000000001','65000000-0000-4000-8000-000000000001','Assigned','Student','5','25000000-0000-4000-8000-000000000001'),
('75000000-0000-4000-8000-000000000002','65000000-0000-4000-8000-000000000002','Unassigned','Student','5','25000000-0000-4000-8000-000000000001');
insert into public.sessions (id,student_id,parent_id,tutor_id,start_time,end_time) values
('85000000-0000-4000-8000-000000000001','75000000-0000-4000-8000-000000000001','65000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001',now(),now()+interval '1 hour'),
('85000000-0000-4000-8000-000000000002','75000000-0000-4000-8000-000000000002','65000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000002',now(),now()+interval '1 hour');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.tutor_profiles),1::bigint,'a tutor can view only their own tutor profile');
select is(public.mac_current_tutor_id(),'55000000-0000-4000-8000-000000000001','an organization-scoped tutor role works for a site-linked tutor profile');
select lives_ok($$update public.tutor_profiles set bio='Updated biography' where id='55000000-0000-4000-8000-000000000001'$$,'a tutor can update their own public profile fields');
select throws_ok($$update public.tutor_profiles set approval_status='approved' where id='55000000-0000-4000-8000-000000000001'$$,'42501','permission denied for table tutor_profiles','a tutor cannot self-approve their profile');
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
insert into auth.users (id,email) values ('15000000-0000-4000-8000-000000000003','legacy-tutor-admin@example.test');
insert into public.profiles (id,user_id,full_name,email,organization_id,role) values ('65000000-0000-4000-8000-000000000003','15000000-0000-4000-8000-000000000003','Legacy Tutor Admin','legacy-tutor-admin@example.test','25000000-0000-4000-8000-000000000001','admin');
insert into public.profiles (id,user_id,full_name,email,organization_id) values ('65000000-0000-4000-8000-000000000005','15000000-0000-4000-8000-000000000005','Foreign Replacement','foreign-replacement@example.test','25000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select lives_ok($$select public.mac_admin_update_tutor_profile('55000000-0000-4000-8000-000000000001','approved')$$,'an authorized administrator can approve a tutor through the protected-field RPC');
select is((select approval_status from public.tutor_profiles where id='55000000-0000-4000-8000-000000000001'),'approved'::approval_status,'the administrative RPC updates protected tutor fields');
select throws_ok($$select public.mac_admin_update_tutor_profile('55000000-0000-4000-8000-000000000001',null,null,null,null,null,null,'65000000-0000-4000-8000-000000000005')$$,'42501','replacement profile is outside the authorized organization','an administrator cannot replace a tutor profile with a foreign-tenant profile');
select lives_ok($$select public.mac_admin_update_tutor_profile('55000000-0000-4000-8000-000000000001',null,22)$$,'an authorized administrator can set a nullable protected field');
select lives_ok($$select public.mac_admin_clear_tutor_profile_fields('55000000-0000-4000-8000-000000000001',true)$$,'an authorized administrator can explicitly clear a nullable protected field');
select is((select hourly_rate from public.tutor_profiles where id='55000000-0000-4000-8000-000000000001'),null::numeric,'the clear RPC removes the requested nullable field');
reset role;
insert into public.users (id,account_status) values ('15000000-0000-4000-8000-000000000003','active');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*) from public.tutor_profiles),0::bigint,'a migrated legacy admin cannot read tutor profiles without enterprise authorization');
select throws_ok($$select public.mac_admin_update_tutor_profile('55000000-0000-4000-8000-000000000001','approved')$$,'42501','not authorized to manage this tutor profile','a migrated legacy admin cannot use tutor administration RPCs');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select is((select count(*) from public.tutor_profiles),2::bigint,'an organization administrator can view tutor profiles in their organization');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{}',true);
select ok(not public.mac_tutor_is_assigned_to_student('75000000-0000-4000-8000-000000000001'),'unauthenticated callers cannot resolve tutor assignments');
reset role;
select * from finish();
rollback;
