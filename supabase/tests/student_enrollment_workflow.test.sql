begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(24);

insert into auth.users (id, email) values
  ('a1000000-0000-4000-8000-000000000001', 'platform-enrollment@example.test'),
  ('a1000000-0000-4000-8000-000000000002', 'org-a-admin@example.test'),
  ('a1000000-0000-4000-8000-000000000003', 'org-b-admin@example.test'),
  ('a1000000-0000-4000-8000-000000000004', 'guardian-a@example.test'),
  ('a1000000-0000-4000-8000-000000000005', 'guardian-b@example.test'),
  ('a1000000-0000-4000-8000-000000000006', 'tutor-a@example.test');

insert into public.organizations (id, name, slug) values
  ('b1000000-0000-4000-8000-000000000001', 'Enrollment Organization A', 'enrollment-org-a'),
  ('b1000000-0000-4000-8000-000000000002', 'Enrollment Organization B', 'enrollment-org-b');

insert into public.sites (id, organization_id, name, code) values
  ('c1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'Enrollment Site A', 'ENR-A'),
  ('c1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000002', 'Enrollment Site B', 'ENR-B');

insert into public.people (id, first_name, last_name, primary_email) values
  ('d1000000-0000-4000-8000-000000000001', 'Platform', 'Admin', 'platform-enrollment@example.test'),
  ('d1000000-0000-4000-8000-000000000002', 'Organization A', 'Admin', 'org-a-admin@example.test'),
  ('d1000000-0000-4000-8000-000000000003', 'Organization B', 'Admin', 'org-b-admin@example.test'),
  ('d1000000-0000-4000-8000-000000000004', 'Guardian', 'Alpha', 'guardian-a@example.test'),
  ('d1000000-0000-4000-8000-000000000005', 'Guardian', 'Beta', 'guardian-b@example.test'),
  ('d1000000-0000-4000-8000-000000000006', 'Tutor', 'Alpha', 'tutor-a@example.test');

insert into public.users (id, person_id, account_status) values
  ('a1000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', 'active'),
  ('a1000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000002', 'active'),
  ('a1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000003', 'active'),
  ('a1000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000004', 'invited'),
  ('a1000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000005', 'active'),
  ('a1000000-0000-4000-8000-000000000006', 'd1000000-0000-4000-8000-000000000006', 'active');

insert into public.profiles (id, user_id, full_name, email, role, organization_id, site_id, person_id, enterprise_user_id) values
  ('e1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'Platform Admin', 'platform-enrollment@example.test', 'admin', null, null, 'd1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001'),
  ('e1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002', 'Organization A Admin', 'org-a-admin@example.test', 'admin', 'b1000000-0000-4000-8000-000000000001', null, 'd1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002'),
  ('e1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000003', 'Organization B Admin', 'org-b-admin@example.test', 'admin', 'b1000000-0000-4000-8000-000000000002', null, 'd1000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000003'),
  ('e1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000004', 'Guardian Alpha', 'guardian-a@example.test', 'parent', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000004'),
  ('e1000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000005', 'Guardian Beta', 'guardian-b@example.test', 'parent', 'b1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000005'),
  ('e1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000006', 'Tutor Alpha', 'tutor-a@example.test', 'tutor', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000006');

insert into public.role_assignments (user_id, organization_id, site_id, role_key, status) values
  ('a1000000-0000-4000-8000-000000000001', null, null, 'platform_admin', 'active'),
  ('a1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', null, 'organization_admin', 'active'),
  ('a1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000002', null, 'organization_admin', 'active'),
  ('a1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'guardian', 'active'),
  ('a1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000002', 'guardian', 'active'),
  ('a1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'tutor', 'active');

select ok(
  has_function_privilege('authenticated', 'public.mac_admin_enroll_student(text,text,text,text,uuid,uuid,date,text,uuid,text)', 'EXECUTE'),
  'authenticated may call enrollment function'
);
select ok(
  not has_function_privilege('anon', 'public.mac_admin_enroll_student(text,text,text,text,uuid,uuid,date,text,uuid,text)', 'EXECUTE'),
  'anon cannot call enrollment function'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok(
  $$select public.mac_admin_enroll_student('Real', 'Learner', 'Grade 4', 'Example Elementary', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date, 'active', 'a1000000-0000-4000-8000-000000000004', 'parent_guardian')$$,
  'platform admin enrolls a student with an invited guardian'
);
reset role;

select is((select count(*) from public.students where first_name = 'Real' and last_name = 'Learner'), 1::bigint, 'student row is created');
select ok((select person_id is not null from public.students where first_name = 'Real' and last_name = 'Learner'), 'student is linked to a canonical person');
select is((select count(*) from public.guardians where person_id = 'd1000000-0000-4000-8000-000000000004'), 1::bigint, 'guardian participant is created');
select is((select count(*) from public.guardian_student_relationships relationship join public.students student on student.id = relationship.student_id where student.first_name = 'Real' and relationship.educational_access), 1::bigint, 'educational guardian relationship is created');
select is((select actor_user_id from public.student_enrollment_events limit 1), 'a1000000-0000-4000-8000-000000000001'::uuid, 'audit event records the administrator actor');
select is(
  (select constraint_definition.confdeltype::text
   from pg_catalog.pg_constraint constraint_definition
   where constraint_definition.conrelid = 'public.student_enrollment_events'::regclass
     and constraint_definition.contype = 'f'
     and constraint_definition.conkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'public.student_enrollment_events'::regclass and attname = 'student_id')]::smallint[]),
  'r',
  'student deletion is restricted to preserve enrollment audit history'
);
select ok((select enterprise_status = 'active' and enrollment_start_date = current_date from public.students where first_name = 'Real'), 'status and enrollment date are preserved');
select is((select parent_id from public.students where first_name = 'Real'), null::uuid, 'canonical enrollment is decoupled from the guardian login profile');

update public.guardians
set status = 'restricted'
where person_id = 'd1000000-0000-4000-8000-000000000004';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $$select public.mac_admin_enroll_student('Restricted', 'Guardian', 'Grade 4', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date, 'active', 'a1000000-0000-4000-8000-000000000004', 'guardian')$$,
  'P0001', 'The selected guardian is not active and must be reactivated separately', 'restricted guardian cannot be used for a new enrollment'
);
reset role;
select is((select status from public.guardians where person_id = 'd1000000-0000-4000-8000-000000000004'), 'restricted', 'enrollment does not reactivate a restricted guardian');
update public.guardians
set status = 'active'
where person_id = 'd1000000-0000-4000-8000-000000000004';

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok(
  $$select public.mac_admin_enroll_student('Cross', 'Tenant', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000002', current_date, 'active', 'a1000000-0000-4000-8000-000000000005', 'guardian')$$,
  'P0001', 'Not authorized to enroll students in this organization', 'organization admin cannot enroll across tenants'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $$select public.mac_admin_enroll_student('Wrong', 'Site', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000002', current_date, 'active', 'a1000000-0000-4000-8000-000000000004', 'guardian')$$,
  'P0001', 'The selected site is not active in this organization', 'cross-tenant site is rejected'
);
select throws_ok(
  $$select public.mac_admin_enroll_student('Wrong', 'Guardian', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date, 'active', 'a1000000-0000-4000-8000-000000000005', 'guardian')$$,
  'P0001', 'The selected guardian is not invited or active in this organization and site', 'cross-tenant guardian is rejected'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
select throws_ok(
  $$select public.mac_admin_enroll_student('Unauthorized', 'Student', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date, 'active', 'a1000000-0000-4000-8000-000000000004', 'guardian')$$,
  'P0001', 'Not authorized to enroll students in this organization', 'Tutor cannot enroll students'
);
select throws_ok(
  $$insert into public.student_enrollment_events (student_id, organization_id, site_id, guardian_id, event_type) select student.id, student.organization_id, student.primary_site_id, relationship.guardian_id, 'updated' from public.students student join public.guardian_student_relationships relationship on relationship.student_id = student.id where student.first_name = 'Real'$$,
  '42501', null, 'authenticated users cannot write audit rows directly'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $$select public.mac_admin_enroll_student('Invalid', 'Status', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date, 'withdrawn', 'a1000000-0000-4000-8000-000000000004', 'guardian')$$,
  'P0001', 'New enrollment status must be active or inactive', 'unsupported initial status is rejected'
);
select throws_ok(
  $$select public.mac_admin_enroll_student('Null', 'Status', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date, null, 'a1000000-0000-4000-8000-000000000004', 'guardian')$$,
  'P0001', 'New enrollment status must be active or inactive', 'null initial status is rejected'
);
select throws_ok(
  $$select public.mac_admin_enroll_student('Invalid', 'Relationship', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date, 'active', 'a1000000-0000-4000-8000-000000000004', 'unsupported')$$,
  'P0001', 'Guardian relationship type is invalid', 'unsupported guardian relationship is rejected'
);
select throws_ok(
  $$select public.mac_admin_enroll_student('Future', 'Inactive', 'Grade 5', '', 'b1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', current_date + 1, 'inactive', 'a1000000-0000-4000-8000-000000000004', 'guardian')$$,
  'P0001', 'Enrollment start date cannot be in the future', 'future enrollment is rejected until scheduling activation exists'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*) from public.student_enrollment_events), 1::bigint, 'own organization admin can view enrollment audit');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*) from public.student_enrollment_events), 0::bigint, 'other organization admin cannot view enrollment audit');
reset role;

select * from finish();
rollback;
