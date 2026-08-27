begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(14);
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
insert into public.guardians (id,organization_id,person_id,status) values ('44000000-0000-4000-8000-000000000001','24000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000001','active');
insert into public.students (id,parent_id,first_name,last_name,grade_level,organization_id,person_id) values
('74000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001','Related','Student','5','24000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000002'),
('74000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000001','Unrelated','Student','5','24000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000003'),
('74000000-0000-4000-8000-000000000003','64000000-0000-4000-8000-000000000001','Restricted','Student','5',null,'34000000-0000-4000-8000-000000000004');
insert into public.guardian_student_relationships (organization_id,guardian_id,student_id,relationship_type,educational_access,valid_from,valid_until) values ('24000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001','parent',true,current_date-1,current_date+1);
select ok(has_table_privilege('authenticated','public.students','select') and has_table_privilege('authenticated','public.guardians','select') and has_table_privilege('authenticated','public.guardian_student_relationships','select'),'authenticated users retain table SELECT privileges while RLS controls family rows');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.guardians),1::bigint,'a guardian can view only their own guardian record');
select is((select count(*) from public.guardian_student_relationships),1::bigint,'a guardian can view only active educational relationships');
select is((select count(*) from public.students),1::bigint,'a guardian can view a student linked by an active educational relationship');
select is((select first_name from public.students where id='74000000-0000-4000-8000-000000000001'),'Related','the related student remains visible to the guardian');
select is((select count(*) from public.students where id='74000000-0000-4000-8000-000000000002'),0::bigint,'an unrelated student is hidden from the guardian');
select is((select count(*) from public.students where id='74000000-0000-4000-8000-000000000003'),0::bigint,'a null student organization uses the legacy parent profile scope');
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