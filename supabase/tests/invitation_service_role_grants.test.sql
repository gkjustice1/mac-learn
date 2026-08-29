begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(12);

select ok(
  has_table_privilege('service_role', 'public.people', 'select'),
  'service_role can read the person created by invitation provisioning'
);
select ok(
  has_table_privilege('service_role', 'public.people', 'insert'),
  'service_role can create an invitation person'
);
select ok(
  has_table_privilege('service_role', 'public.people', 'delete'),
  'service_role can roll back an invitation person after failure'
);
select ok(
  not has_table_privilege('service_role', 'public.people', 'update'),
  'service_role cannot update people through the Data API'
);

select ok(
  has_table_privilege('service_role', 'public.users', 'insert'),
  'service_role can create an invited enterprise identity'
);
select ok(
  not has_table_privilege('service_role', 'public.users', 'select'),
  'service_role cannot read enterprise identities through the Data API'
);
select ok(
  not has_table_privilege('service_role', 'public.users', 'update'),
  'service_role cannot update enterprise identities through the Data API'
);
select ok(
  not has_table_privilege('service_role', 'public.users', 'delete'),
  'service_role cannot delete enterprise identities through the Data API'
);

select ok(
  has_table_privilege('service_role', 'public.profiles', 'insert'),
  'service_role can create an invited user profile'
);
select ok(
  not has_table_privilege('service_role', 'public.profiles', 'select'),
  'service_role cannot read profiles through the Data API'
);
select ok(
  not has_table_privilege('service_role', 'public.profiles', 'update'),
  'service_role cannot update profiles through the Data API'
);
select ok(
  not has_table_privilege('service_role', 'public.profiles', 'delete'),
  'service_role cannot delete profiles through the Data API'
);

select * from finish();
rollback;
