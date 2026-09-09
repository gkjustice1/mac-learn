with
table_acl_rows as (
  select concat_ws('|', n.nspname, c.relname, coalesce(r.rolname, 'PUBLIC'),
    x.privilege_type, x.is_grantable::text) as canonical
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) x
  left join pg_roles r on r.oid = x.grantee
  where n.nspname = 'public' and c.relkind in ('r', 'p')
),
column_acl_rows as (
  select concat_ws('|', n.nspname, c.relname, a.attname,
    coalesce(r.rolname, 'PUBLIC'), x.privilege_type, x.is_grantable::text) as canonical
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(coalesce(a.attacl, '{}'::aclitem[])) x
  left join pg_roles r on r.oid = x.grantee
  where n.nspname = 'public' and a.attnum > 0 and not a.attisdropped
),
function_acl_rows as (
  select concat_ws('|', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
    coalesce(r.rolname, 'PUBLIC'), x.privilege_type, x.is_grantable::text) as canonical
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
  left join pg_roles r on r.oid = x.grantee
  where n.nspname = 'public' and p.proname <> 'rls_auto_enable'
),
constraint_rows as (
  select concat_ws('|', n.nspname, coalesce(c.relname, ''), con.conname,
    con.contype, con.condeferrable::text, con.condeferred::text,
    con.convalidated::text, pg_get_constraintdef(con.oid, true)) as canonical
  from pg_constraint con
  join pg_namespace n on n.oid = con.connamespace
  left join pg_class c on c.oid = con.conrelid
  where n.nspname = 'public'
),
function_rows as (
  select concat_ws('|', p.proname, pg_get_function_identity_arguments(p.oid),
    pg_get_function_result(p.oid), l.lanname, p.provolatile, p.prosecdef::text,
    p.proparallel, p.proisstrict::text, p.proleakproof::text,
    coalesce(array_to_string(p.proconfig, ','), ''),
    regexp_replace(btrim(p.prosrc), '[[:space:]]+', ' ', 'g')) as canonical
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_language l on l.oid = p.prolang
  where n.nspname = 'public' and p.proname <> 'rls_auto_enable'
),
rls_policy_rows as (
  select concat_ws('|', n.nspname, c.relname, pol.polname, pol.polpermissive::text,
    pol.polcmd,
    coalesce((select string_agg(coalesce(r.rolname, 'PUBLIC'), ',' order by coalesce(r.rolname, 'PUBLIC'))
      from unnest(pol.polroles) role_oid
      left join pg_roles r on r.oid = role_oid), ''),
    coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), ''),
    coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), '')) as canonical
  from pg_policy pol
  join pg_class c on c.oid = pol.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
),
index_rows as (
  select concat_ws('|', n.nspname, i.relname, t.relname,
    x.indisunique::text, x.indisprimary::text, x.indisexclusion::text,
    x.indimmediate::text, x.indisvalid::text, x.indisready::text,
    x.indislive::text, x.indisreplident::text, pg_get_indexdef(x.indexrelid)) as canonical
  from pg_index x
  join pg_class i on i.oid = x.indexrelid
  join pg_class t on t.oid = x.indrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
),
rls_table_rows as (
  select concat_ws('|', n.nspname, c.relname, c.relrowsecurity::text,
    c.relforcerowsecurity::text) as canonical
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p')
),
column_rows as (
  select concat_ws('|', table_schema, table_name, ordinal_position::text, column_name,
    data_type, udt_schema, udt_name, is_nullable, coalesce(column_default, ''),
    coalesce(is_identity, ''), coalesce(identity_generation, ''),
    coalesce(is_generated, ''), coalesce(generation_expression, '')) as canonical
  from information_schema.columns
  where table_schema = 'public'
),
enum_rows as (
  select concat_ws('|', n.nspname, t.typname, e.enumsortorder::text, e.enumlabel) as canonical
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  join pg_enum e on e.enumtypid = t.oid
  where n.nspname = 'public'
),
trigger_rows as (
  select concat_ws('|', n.nspname, c.relname, t.tgname, pg_get_triggerdef(t.oid, true)) as canonical
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and not t.tgisinternal
),
migration_rows as (
  select concat_ws('|', version, name) as canonical
  from supabase_migrations.schema_migrations
),
audit as (
  select 'table_acl' as category, canonical from table_acl_rows
  union all select 'column_acl', canonical from column_acl_rows
  union all select 'function_acl', canonical from function_acl_rows
  union all select 'constraints', canonical from constraint_rows
  union all select 'functions', canonical from function_rows
  union all select 'rls_policies', canonical from rls_policy_rows
  union all select 'indexes', canonical from index_rows
  union all select 'rls_tables', canonical from rls_table_rows
  union all select 'columns', canonical from column_rows
  union all select 'enums', canonical from enum_rows
  union all select 'triggers', canonical from trigger_rows
  union all select 'migrations', canonical from migration_rows
  union all
  select 'storage_bucket', concat_ws('|', id, name, public::text,
    coalesce(file_size_limit::text, ''), coalesce(array_to_string(allowed_mime_types, ','), ''))
  from storage.buckets where id = 'mac-reads-audio'
)
select category, count(*)::bigint as row_count,
  md5(coalesce(string_agg(canonical, E'\n' order by canonical), '')) as digest
from audit
group by category
order by category;
