begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(20);

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
