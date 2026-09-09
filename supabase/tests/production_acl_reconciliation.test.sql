begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(23);

create temporary table expected_maintain_acl (
  grantee text not null,
  table_name text not null,
  privilege_type text not null default 'MAINTAIN',
  is_grantable boolean not null default false,
  primary key (grantee, table_name, privilege_type)
) on commit drop;

insert into expected_maintain_acl (grantee, table_name)
select 'anon', table_name
from unnest(array[
  'classroom_educators',
  'classroom_student_enrollments',
  'classrooms',
  'educator_instructional_records',
  'guardian_student_relationships',
  'guardians',
  'homework_uploads',
  'organization_configurations',
  'organizations',
  'payments',
  'people',
  'profiles',
  'progress_reports',
  'role_assignment_events',
  'role_assignments',
  'session_notes',
  'sessions',
  'sites',
  'staff',
  'students',
  'subjects',
  'tutor_availability',
  'tutor_profiles',
  'users'
]::text[]) as expected(table_name);

insert into expected_maintain_acl (grantee, table_name)
select 'authenticated', table_name
from unnest(array[
  'classroom_educators',
  'classroom_student_enrollments',
  'classrooms',
  'educator_instructional_records',
  'guardian_student_relationships',
  'guardians',
  'homework_uploads',
  'organization_configurations',
  'organizations',
  'payments',
  'people',
  'profiles',
  'progress_reports',
  'role_assignments',
  'session_notes',
  'sessions',
  'sites',
  'staff',
  'student_enrollment_events',
  'students',
  'subjects',
  'tutor_availability',
  'tutor_profiles',
  'users'
]::text[]) as expected(table_name);

insert into expected_maintain_acl (grantee, table_name)
select 'service_role', table_name
from unnest(array[
  'classroom_educators',
  'classroom_student_enrollments',
  'classrooms',
  'educator_instructional_records',
  'guardian_student_relationships',
  'guardians',
  'homework_uploads',
  'mac_reads_audio_assets',
  'organization_configurations',
  'organizations',
  'payments',
  'people',
  'profiles',
  'progress_reports',
  'role_assignment_events',
  'role_assignments',
  'session_notes',
  'session_status_events',
  'sessions',
  'sites',
  'staff',
  'student_enrollment_events',
  'students',
  'subjects',
  'tutor_availability',
  'tutor_profiles',
  'users'
]::text[]) as expected(table_name);

select ok(not has_table_privilege('anon', 'public.students', 'select'), 'anon cannot select students');
select ok(not has_table_privilege('anon', 'public.organizations', 'select'), 'anon cannot select organizations');
select ok(not has_table_privilege('anon', 'public.mac_reads_audio_assets', 'select'), 'anon cannot select MAC READS audio registry');

select ok(has_table_privilege('authenticated', 'public.students', 'select'), 'authenticated can select students subject to RLS');
select ok(not has_table_privilege('authenticated', 'public.students', 'insert'), 'authenticated cannot directly insert students');
select ok(has_table_privilege('authenticated', 'public.profiles', 'select'), 'authenticated can select profiles subject to RLS');
select ok(has_column_privilege('authenticated', 'public.profiles', 'full_name', 'update'), 'authenticated can update own profile full_name subject to RLS');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'email', 'update'), 'authenticated cannot update profile email directly');
select ok(has_column_privilege('authenticated', 'public.tutor_profiles', 'bio', 'update'), 'authenticated tutor can update bio subject to RLS');
select ok(not has_column_privilege('authenticated', 'public.tutor_profiles', 'hourly_rate', 'update'), 'authenticated tutor cannot update hourly rate directly');

select ok(not has_table_privilege('service_role', 'public.people', 'select'), 'service_role has no blanket people SELECT');
select ok(has_table_privilege('service_role', 'public.organization_configurations', 'select'), 'service_role can read organization configuration');
select ok(has_table_privilege('service_role', 'public.organization_configurations', 'update'), 'service_role can update organization configuration');

select ok(has_function_privilege('service_role', 'public.mac_create_invited_enterprise_identity(uuid,text,text,text,uuid,uuid)', 'execute'), 'service_role can execute invitation identity creation');
select ok(not has_function_privilege('authenticated', 'public.mac_create_invited_enterprise_identity(uuid,text,text,text,uuid,uuid)', 'execute'), 'authenticated cannot execute invitation identity creation');
select ok(has_function_privilege('authenticated', 'public.mac_current_user_roles()', 'execute'), 'authenticated can execute authorization context RPC');
select ok(not has_function_privilege('anon', 'public.mac_current_user_roles()', 'execute'), 'anon cannot execute authorization context RPC');
select ok(has_function_privilege('anon', 'public.mac_set_updated_at()', 'execute'), 'anon retains production-equivalent trigger-helper EXECUTE');

select is(
  (
    select count(*)::bigint
    from pg_class as table_definition
    join pg_namespace as schema_definition
      on schema_definition.oid = table_definition.relnamespace
    cross join lateral aclexplode(
      coalesce(table_definition.relacl, acldefault('r', table_definition.relowner))
    ) as acl
    join pg_roles as grantee_role
      on grantee_role.oid = acl.grantee
    where schema_definition.nspname = 'public'
      and table_definition.relkind in ('r', 'p')
      and grantee_role.rolname in ('anon', 'authenticated', 'service_role')
      and acl.privilege_type = 'MAINTAIN'
      and not acl.is_grantable
  ),
  75::bigint,
  'public tables expose exactly 75 production-normalized API-role MAINTAIN grants'
);

select ok(
  not exists (
    select 1
    from pg_class as table_definition
    join pg_namespace as schema_definition
      on schema_definition.oid = table_definition.relnamespace
    cross join lateral aclexplode(
      coalesce(table_definition.relacl, acldefault('r', table_definition.relowner))
    ) as acl
    join pg_roles as grantee_role
      on grantee_role.oid = acl.grantee
    left join expected_maintain_acl as expected
      on expected.grantee = grantee_role.rolname
      and expected.table_name = table_definition.relname
      and expected.privilege_type = acl.privilege_type
      and expected.is_grantable = acl.is_grantable
    where schema_definition.nspname = 'public'
      and table_definition.relkind in ('r', 'p')
      and grantee_role.rolname in ('anon', 'authenticated', 'service_role')
      and acl.privilege_type = 'MAINTAIN'
      and expected.grantee is null
  ),
  'public tables have no unexpected normalized API-role MAINTAIN grants'
);

select ok(
  not exists (
    select 1
    from expected_maintain_acl as expected
    left join (
      select
        grantee_role.rolname as grantee,
        table_definition.relname as table_name,
        acl.privilege_type,
        acl.is_grantable
      from pg_class as table_definition
      join pg_namespace as schema_definition
        on schema_definition.oid = table_definition.relnamespace
      cross join lateral aclexplode(
        coalesce(table_definition.relacl, acldefault('r', table_definition.relowner))
      ) as acl
      join pg_roles as grantee_role
        on grantee_role.oid = acl.grantee
      where schema_definition.nspname = 'public'
        and table_definition.relkind in ('r', 'p')
        and grantee_role.rolname in ('anon', 'authenticated', 'service_role')
        and acl.privilege_type = 'MAINTAIN'
    ) as actual
      on actual.grantee = expected.grantee
      and actual.table_name = expected.table_name
      and actual.privilege_type = expected.privilege_type
      and actual.is_grantable = expected.is_grantable
    where actual.grantee is null
  ),
  'public tables have no missing normalized API-role MAINTAIN grants'
);

select is(
  (
    select coalesce(
      string_agg(
        concat(
          coalesce(grantee_role.rolname::text, 'PUBLIC'),
          ':',
          acl.privilege_type,
          ':',
          acl.is_grantable::text
        ),
        ','
        order by coalesce(grantee_role.rolname::text, 'PUBLIC'), acl.privilege_type, acl.is_grantable
      ),
      ''
    )
    from pg_proc as function_definition
    cross join lateral aclexplode(
      coalesce(
        function_definition.proacl,
        acldefault('f', function_definition.proowner)
      )
    ) as acl
    left join pg_roles as grantee_role
      on grantee_role.oid = acl.grantee
    where function_definition.oid = 'public.mac_set_updated_at()'::regprocedure
      and acl.grantee <> function_definition.proowner
  ),
  'PUBLIC:EXECUTE:false',
  'mac_set_updated_at has the exact production-normalized non-owner ACL'
);

select is(
  (
    select count(*)::bigint
    from pg_proc as function_definition
    cross join lateral aclexplode(
      coalesce(function_definition.proacl, '{}'::aclitem[])
    ) as acl
    where function_definition.oid = 'public.mac_set_updated_at()'::regprocedure
      and acl.grantee in (
        select role_definition.oid
        from pg_roles as role_definition
        where role_definition.rolname in ('anon', 'authenticated', 'service_role')
      )
  ),
  0::bigint,
  'mac_set_updated_at has no direct API-role EXECUTE grants'
);

select * from finish();
rollback;
