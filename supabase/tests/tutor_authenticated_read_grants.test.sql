begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(13);

select ok(
  has_table_privilege('authenticated', 'public.students', 'select'),
  'authenticated users can query students through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.sessions', 'select'),
  'authenticated users can query sessions through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.subjects', 'select'),
  'authenticated users can query session subjects through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.tutor_availability', 'select'),
  'authenticated users can query tutor availability through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.session_notes', 'select'),
  'authenticated users can query session notes through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.progress_reports', 'select'),
  'authenticated users can query progress reports through RLS'
);

select ok(
  not has_table_privilege('anon', 'public.students', 'select'),
  'anonymous users cannot query students'
);
select ok(
  not has_table_privilege('anon', 'public.sessions', 'select'),
  'anonymous users cannot query sessions'
);
select ok(
  not has_table_privilege('anon', 'public.subjects', 'select'),
  'anonymous users cannot query subjects'
);
select ok(
  not has_table_privilege('anon', 'public.tutor_availability', 'select'),
  'anonymous users cannot query tutor availability'
);
select ok(
  not has_table_privilege('anon', 'public.session_notes', 'select'),
  'anonymous users cannot query session notes'
);
select ok(
  not has_table_privilege('anon', 'public.progress_reports', 'select'),
  'anonymous users cannot query progress reports'
);

select is(
  (
    select count(*)
    from pg_class
    where oid in (
      'public.students'::regclass,
      'public.sessions'::regclass,
      'public.subjects'::regclass,
      'public.tutor_availability'::regclass,
      'public.session_notes'::regclass,
      'public.progress_reports'::regclass
    )
      and relrowsecurity
  ),
  6::bigint,
  'RLS remains enabled on every Tutor workspace table'
);

select * from finish();
rollback;
