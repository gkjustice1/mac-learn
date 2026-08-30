begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(18);

insert into auth.users (id, email) values
  ('18000000-0000-4000-8000-000000000001', 'operations-admin@example.test'),
  ('18000000-0000-4000-8000-000000000002', 'operations-tutor@example.test'),
  ('18000000-0000-4000-8000-000000000003', 'foreign-tutor@example.test');

insert into public.organizations (id, name, slug) values
  ('28000000-0000-4000-8000-000000000001', 'Operations Organization', 'operations-organization'),
  ('28000000-0000-4000-8000-000000000002', 'Foreign Operations Organization', 'foreign-operations-organization');

insert into public.sites (id, organization_id, name, code) values
  ('38000000-0000-4000-8000-000000000001', '28000000-0000-4000-8000-000000000001', 'Operations Site', 'OPS'),
  ('38000000-0000-4000-8000-000000000002', '28000000-0000-4000-8000-000000000002', 'Foreign Site', 'FOREIGN');

insert into public.users (id, account_status) values
  ('18000000-0000-4000-8000-000000000001', 'active'),
  ('18000000-0000-4000-8000-000000000002', 'active'),
  ('18000000-0000-4000-8000-000000000003', 'active');

insert into public.profiles (id, user_id, full_name, email, organization_id) values
  ('68000000-0000-4000-8000-000000000001', '18000000-0000-4000-8000-000000000001', 'Operations Admin', 'operations-admin@example.test', null),
  ('68000000-0000-4000-8000-000000000002', '18000000-0000-4000-8000-000000000002', 'Operations Tutor', 'operations-tutor@example.test', '28000000-0000-4000-8000-000000000001'),
  ('68000000-0000-4000-8000-000000000003', '18000000-0000-4000-8000-000000000003', 'Foreign Tutor', 'foreign-tutor@example.test', '28000000-0000-4000-8000-000000000002');

insert into public.tutor_profiles (id, user_id, organization_id, site_id) values
  ('58000000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000002', '28000000-0000-4000-8000-000000000001', '38000000-0000-4000-8000-000000000001'),
  ('58000000-0000-4000-8000-000000000002', '68000000-0000-4000-8000-000000000003', '28000000-0000-4000-8000-000000000002', '38000000-0000-4000-8000-000000000002');

insert into public.role_assignments (user_id, role_key, organization_id, site_id, status) values
  ('18000000-0000-4000-8000-000000000001', 'platform_admin', null, null, 'active'),
  ('18000000-0000-4000-8000-000000000002', 'tutor', '28000000-0000-4000-8000-000000000001', '38000000-0000-4000-8000-000000000001', 'active'),
  ('18000000-0000-4000-8000-000000000003', 'tutor', '28000000-0000-4000-8000-000000000002', '38000000-0000-4000-8000-000000000002', 'active');

insert into public.students (
  id, parent_id, first_name, last_name, grade_level, organization_id, primary_site_id
) values
  ('78000000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', 'Assigned', 'Learner', '4', '28000000-0000-4000-8000-000000000001', '38000000-0000-4000-8000-000000000001'),
  ('78000000-0000-4000-8000-000000000002', '68000000-0000-4000-8000-000000000001', 'Foreign', 'Learner', '4', '28000000-0000-4000-8000-000000000002', '38000000-0000-4000-8000-000000000002');

insert into public.subjects (id, name, grade_band)
values ('88000000-0000-4000-8000-000000000001', 'Operational Reading', '3-5');

select ok(
  has_table_privilege('authenticated', 'public.tutor_availability', 'insert'),
  'authenticated Tutors can insert availability through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.session_notes', 'insert'),
  'authenticated Tutors can insert session notes through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.progress_reports', 'insert'),
  'authenticated Tutors can insert progress reports through RLS'
);
select ok(
  not has_table_privilege('anon', 'public.tutor_availability', 'insert')
  and not has_table_privilege('anon', 'public.session_notes', 'insert')
  and not has_table_privilege('anon', 'public.progress_reports', 'insert'),
  'anonymous users receive no Tutor workflow write grants'
);
select ok(
  has_function_privilege('authenticated', 'public.mac_platform_admin_schedule_session(uuid,uuid,uuid,timestamptz,timestamptz,text)', 'execute'),
  'authenticated users can invoke the self-authorizing scheduling function'
);
select ok(
  not has_function_privilege('anon', 'public.mac_platform_admin_schedule_session(uuid,uuid,uuid,timestamptz,timestamptz,text)', 'execute'),
  'anonymous users cannot invoke session scheduling'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select is(
  (select count(*) from public.mac_platform_admin_student_options()),
  2::bigint,
  'Platform Admin receives active enterprise student options'
);
select is(
  (select count(*) from public.mac_platform_admin_tutor_options()),
  2::bigint,
  'Platform Admin receives active Tutor options'
);
select lives_ok(
  $$select public.mac_platform_admin_schedule_session(
    '78000000-0000-4000-8000-000000000001',
    '58000000-0000-4000-8000-000000000001',
    '88000000-0000-4000-8000-000000000001',
    now() + interval '1 day',
    now() + interval '1 day 1 hour',
    'https://example.test/session'
  )$$,
  'Platform Admin can assign a same-scope student session'
);
select throws_ok(
  $$select public.mac_platform_admin_schedule_session(
    '78000000-0000-4000-8000-000000000001',
    '58000000-0000-4000-8000-000000000002',
    '88000000-0000-4000-8000-000000000001',
    now() + interval '2 days',
    now() + interval '2 days 1 hour',
    null
  )$$,
  '42501',
  'student and Tutor must belong to the same organization',
  'cross-organization Tutor assignment is rejected'
);

reset role;
select is(
  (select count(*) from public.sessions where student_id = '78000000-0000-4000-8000-000000000001'),
  1::bigint,
  'only the authorized session is created'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

select throws_ok(
  $$select public.mac_platform_admin_schedule_session(
    '78000000-0000-4000-8000-000000000001',
    '58000000-0000-4000-8000-000000000001',
    '88000000-0000-4000-8000-000000000001',
    now() + interval '3 days',
    now() + interval '3 days 1 hour',
    null
  )$$,
  '42501',
  'not authorized to schedule Tutor sessions',
  'a Tutor cannot use the administrator scheduling function'
);
select lives_ok(
  $$insert into public.tutor_availability (tutor_id, day_of_week, start_time, end_time)
    values ('58000000-0000-4000-8000-000000000001', 1, '15:00', '18:00')$$,
  'a Tutor can add their own valid availability window'
);
select throws_ok(
  $$insert into public.tutor_availability (tutor_id, day_of_week, start_time, end_time)
    values ('58000000-0000-4000-8000-000000000001', 2, '18:00', '15:00')$$,
  '23514',
  'new row for relation "tutor_availability" violates check constraint "tutor_availability_valid_window"',
  'an invalid availability window is rejected'
);
select lives_ok(
  $$insert into public.session_notes (session_id, tutor_id, attendance_status, skills_covered)
    select session.id, '58000000-0000-4000-8000-000000000001', 'present', 'Decoding'
    from public.sessions session
    where session.student_id = '78000000-0000-4000-8000-000000000001'$$,
  'a Tutor can add a note to their assigned session'
);
select lives_ok(
  $$insert into public.progress_reports (student_id, tutor_id, subject_id, reporting_period, strengths)
    values (
      '78000000-0000-4000-8000-000000000001',
      '58000000-0000-4000-8000-000000000001',
      '88000000-0000-4000-8000-000000000001',
      'Quarter 1',
      'Growing decoding accuracy'
    )$$,
  'a Tutor can add a progress report for an assigned student'
);
select is(
  (select count(*) from public.session_notes),
  1::bigint,
  'the Tutor sees the created session note'
);
select is(
  (select count(*) from public.progress_reports),
  1::bigint,
  'the Tutor sees the created progress report'
);

reset role;
select * from finish();
rollback;
