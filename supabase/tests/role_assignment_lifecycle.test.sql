begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(16);

insert into auth.users (id, email)
values
  ('10000000-0000-4000-8000-000000000001', 'platform-admin@example.test'),
  ('10000000-0000-4000-8000-000000000002', 'regular-user@example.test');

insert into public.users (id, account_status)
values
  ('10000000-0000-4000-8000-000000000001', 'active'),
  ('10000000-0000-4000-8000-000000000002', 'active');

insert into public.organizations (id, name, slug)
values (
  '20000000-0000-4000-8000-000000000001',
  'Lifecycle Test Organization',
  'lifecycle-test-organization'
);

insert into public.role_assignments (
  id,
  user_id,
  role_key,
  status
) values (
  '30000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'platform_admin',
  'active'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

select ok(
  public.mac_is_platform_admin(),
  'fixture user is authorized as a Platform Admin'
);

insert into public.role_assignments (
  id,
  organization_id,
  user_id,
  role_key,
  status,
  valid_until
) values
  (
    '30000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'teacher',
    'expired',
    now() - interval '2 days'
  ),
  (
    '30000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'teacher',
    'active',
    now() - interval '1 day'
  );

select lives_ok(
  $$
    select public.mac_renew_role_assignment(
      '30000000-0000-4000-8000-000000000002',
      now() + interval '30 days',
      'Renew expired assignment in pgTAP'
    )
  $$,
  'an expired assignment can be renewed'
);

select is(
  (
    select status
    from public.role_assignments
    where id = '30000000-0000-4000-8000-000000000003'
  ),
  'expired',
  'an elapsed exact-scope conflict is reconciled during renewal'
);

select is(
  (
    select count(*)
    from public.role_assignment_events
    where assignment_id = '30000000-0000-4000-8000-000000000003'
      and event_type = 'expired'
      and related_assignment_id is not null
  ),
  0::bigint,
  'nested conflict expiration does not inherit renewal linkage'
);

select is(
  (
    select count(*)
    from public.role_assignment_events
    where related_assignment_id = '30000000-0000-4000-8000-000000000002'
      and event_type = 'renewed'
      and actor_user_id = '10000000-0000-4000-8000-000000000001'
      and reason = 'Renew expired assignment in pgTAP'
      and before_state is null
      and after_state ->> 'status' = 'active'
  ),
  1::bigint,
  'renewal records one linked audit event with actor, reason, and state'
);

select lives_ok(
  format(
    'select public.mac_revoke_role_assignment(%L, %L)',
    (
      select assignment_id
      from public.role_assignment_events
      where related_assignment_id = '30000000-0000-4000-8000-000000000002'
        and event_type = 'renewed'
    ),
    'Revoke replacement in pgTAP'
  ),
  'an active replacement can be revoked'
);

select is(
  (
    select count(*)
    from public.role_assignment_events
    where event_type = 'revoked'
      and reason = 'Revoke replacement in pgTAP'
      and before_state ->> 'status' = 'active'
      and after_state ->> 'status' = 'revoked'
  ),
  1::bigint,
  'revocation records its reason and before/after status'
);

select lives_ok(
  format(
    'select public.mac_renew_role_assignment(%L, null, %L)',
    (
      select assignment_id
      from public.role_assignment_events
      where event_type = 'revoked'
        and reason = 'Revoke replacement in pgTAP'
    ),
    'Renew revoked assignment in pgTAP'
  ),
  'a revoked assignment can be renewed without an expiration date'
);

select lives_ok(
  format(
    'select public.mac_expire_role_assignment(%L, %L)',
    (
      select assignment_id
      from public.role_assignment_events
      where event_type = 'renewed'
        and reason = 'Renew revoked assignment in pgTAP'
    ),
    'Manually expire replacement in pgTAP'
  ),
  'an active assignment can be manually expired'
);

select is(
  (
    select count(*)
    from public.role_assignment_events
    where event_type = 'expired'
      and reason = 'Manually expire replacement in pgTAP'
      and (after_state ->> 'valid_until')::timestamptz <= now()
  ),
  1::bigint,
  'manual expiration records an elapsed valid_until value'
);

select throws_ok(
  $$
    select public.mac_revoke_role_assignment(
      '30000000-0000-4000-8000-000000000002',
      '   '
    )
  $$
);

select throws_ok(
  $$
    select public.mac_renew_role_assignment(
      '30000000-0000-4000-8000-000000000001',
      now() + interval '30 days',
      'Invalid active renewal'
    )
  $$
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    select public.mac_renew_role_assignment(
      '30000000-0000-4000-8000-000000000002',
      now() + interval '30 days',
      'Unauthorized renewal'
    )
  $$
);

select is(
  (
    select count(*)
    from public.role_assignment_events
  ),
  0::bigint,
  'a non-admin cannot view role assignment audit events'
);

select throws_ok(
  $$update public.role_assignment_events set reason = 'tampered'$$
);

select throws_ok(
  $$delete from public.role_assignment_events$$
);

select * from finish();
rollback;
