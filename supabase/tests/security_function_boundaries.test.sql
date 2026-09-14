begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into auth.users (id, email) values
  ('16000000-0000-4000-8000-000000000001', 'assigned-educator@example.test'),
  ('16000000-0000-4000-8000-000000000002', 'other-educator@example.test'),
  ('16000000-0000-4000-8000-000000000003', 'organization-admin@example.test');
insert into public.organizations (id, name, slug) values
  ('26000000-0000-4000-8000-000000000001', 'Educator Access Test Organization', 'educator-access-test');
insert into public.sites (id, organization_id, name, code) values
  ('36000000-0000-4000-8000-000000000001', '26000000-0000-4000-8000-000000000001', 'Educator Access Site', 'EDU');
insert into public.organizations (id, name, slug) values
  ('26000000-0000-4000-8000-000000000002', 'Foreign Educator Access Organization', 'foreign-educator-access-test');
insert into public.sites (id, organization_id, name, code) values
  ('36000000-0000-4000-8000-000000000002', '26000000-0000-4000-8000-000000000002', 'Foreign Educator Access Site', 'EDU-FOREIGN');
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
select throws_ok($$insert into public.classrooms (organization_id, site_id, name, code) values ('26000000-0000-4000-8000-000000000001', '36000000-0000-4000-8000-000000000002', 'Cross Tenant Classroom', 'EDU-X')$$, '23503', 'insert or update on table "classrooms" violates foreign key constraint "classrooms_organization_id_site_id_fkey"', 'a classroom cannot reference a site from another organization');


update public.classroom_educators set assigned_from=current_date-2;
update public.classroom_student_enrollments set enrolled_from=current_date-2;

-- Real foreign targets distinguish authorization failure from missing data.
insert into public.classrooms (id, organization_id, site_id, name, code) values
('86000000-0000-4000-8000-000000000003','26000000-0000-4000-8000-000000000002','36000000-0000-4000-8000-000000000002','Foreign Classroom','FOREIGN');
insert into public.students (id,parent_id,first_name,last_name,grade_level,organization_id) values
('76000000-0000-4000-8000-000000000003','66000000-0000-4000-8000-000000000001','Foreign','Student','5','26000000-0000-4000-8000-000000000002');
-- Choose a date that differs from UTC at every test execution time.
update public.sites set timezone = case
when (now() at time zone 'Pacific/Kiritimati')::date <> (now() at time zone 'UTC')::date
then 'Pacific/Kiritimati' else 'Pacific/Honolulu' end;
update public.organization_configurations set default_timezone = case
when (now() at time zone 'Pacific/Kiritimati')::date <> (now() at time zone 'UTC')::date
then 'Pacific/Kiritimati' else 'Pacific/Honolulu' end;
select set_config('test.expected_calendar_date', (case
when (now() at time zone 'Pacific/Kiritimati')::date <> (now() at time zone 'UTC')::date
then (now() at time zone 'Pacific/Kiritimati')::date
else (now() at time zone 'Pacific/Honolulu')::date end)::text, true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"16000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(public.mac_classroom_calendar_date('86000000-0000-4000-8000-000000000001'), current_setting('test.expected_calendar_date')::date, 'authorized classroom retains site calendar');
select is(public.mac_relationship_calendar_date('76000000-0000-4000-8000-000000000001','26000000-0000-4000-8000-000000000001'), current_setting('test.expected_calendar_date')::date, 'authorized site-less student retains organization calendar');
select is(public.mac_classroom_calendar_date('86000000-0000-4000-8000-000000000003'),null::date,'foreign classroom calendar is hidden');
select is(public.mac_relationship_calendar_date('76000000-0000-4000-8000-000000000003','26000000-0000-4000-8000-000000000002'),null::date,'foreign student calendar is hidden');
select is(public.mac_relationship_calendar_date('76000000-0000-4000-8000-000000000003','26000000-0000-4000-8000-000000000001'),null::date,'forged organization cannot resolve a foreign student');
select is(public.mac_relationship_calendar_date('00000000-0000-0000-0000-000000000000','26000000-0000-4000-8000-000000000001'),null::date,'missing student does not fall back to organization metadata');
select is(public.mac_classroom_calendar_date('00000000-0000-0000-0000-000000000000'),null::date,'missing classroom returns no date');
select ok(public.mac_is_active_classroom_educator('86000000-0000-4000-8000-000000000001'),'educator dependency remains acyclic and authorized');
select is((select count(*) from public.classrooms),1::bigint,'RLS still restricts classroom rows despite organization calendar access');
select set_config('request.jwt.claims','{}',true);
select is(public.mac_classroom_calendar_date('86000000-0000-4000-8000-000000000001'),null::date,'missing identity cannot read classroom calendar');
select is(public.mac_relationship_calendar_date('76000000-0000-4000-8000-000000000001','26000000-0000-4000-8000-000000000001'),null::date,'missing identity cannot read student calendar');
reset role;
-- Expired assignments must not authorize direct RPC calls.
select set_config('mac.audit_reason','Security regression: expire fixture role',true);
update public.role_assignments set valid_until=now()-interval '1 second', valid_from=now()-interval '1 day'
where user_id='16000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"16000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(public.mac_classroom_calendar_date('86000000-0000-4000-8000-000000000001'),null::date,'expired assignment cannot read classroom calendar');
select is(public.mac_relationship_calendar_date('76000000-0000-4000-8000-000000000001','26000000-0000-4000-8000-000000000001'),null::date,'expired assignment cannot read student calendar');
reset role;
select ok(not has_function_privilege('anon','public.mac_classroom_calendar_date(uuid)','execute') and has_function_privilege('authenticated','public.mac_classroom_calendar_date(uuid)','execute'),'restricted EXECUTE ACL: mac_classroom_calendar_date');
select ok(not has_function_privilege('anon','public.mac_relationship_calendar_date(uuid,uuid)','execute') and has_function_privilege('authenticated','public.mac_relationship_calendar_date(uuid,uuid)','execute'),'restricted EXECUTE ACL: mac_relationship_calendar_date');
select ok(not has_function_privilege('anon','public.mac_admin_update_tutor_profile(uuid,approval_status,numeric,uuid,uuid,uuid,uuid,uuid)','execute') and has_function_privilege('authenticated','public.mac_admin_update_tutor_profile(uuid,approval_status,numeric,uuid,uuid,uuid,uuid,uuid)','execute'),'restricted EXECUTE ACL: mac_admin_update_tutor_profile');
select ok(not has_function_privilege('anon','public.mac_admin_clear_tutor_profile_fields(uuid,boolean,boolean,boolean,boolean)','execute') and has_function_privilege('authenticated','public.mac_admin_clear_tutor_profile_fields(uuid,boolean,boolean,boolean,boolean)','execute'),'restricted EXECUTE ACL: mac_admin_clear_tutor_profile_fields');
select ok((select prosrc ~* 'if not public.mac_can_manage_tutor_profile[\s\S]*raise exception[\s\S]*for update;[\s\S]*if not public.mac_can_manage_tutor_profile[\s\S]*raise exception' from pg_proc where oid in (select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mac_admin_update_tutor_profile')), 'mac_admin_update_tutor_profile authorizes before locking and rechecks afterward');
select ok((select prosrc ~* 'if not public.mac_can_manage_tutor_profile[\s\S]*raise exception[\s\S]*for update;[\s\S]*if not public.mac_can_manage_tutor_profile[\s\S]*raise exception' from pg_proc where oid in (select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mac_admin_clear_tutor_profile_fields')), 'mac_admin_clear_tutor_profile_fields authorizes before locking and rechecks afterward');
select * from finish();
rollback;
