-- ============================================================
-- MAC LEARN
-- Role Assignment Lifecycle and Audit History
-- ============================================================

create table public.role_assignment_events (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null
    references public.role_assignments(id) on delete restrict,
  related_assignment_id uuid
    references public.role_assignments(id) on delete restrict,
  actor_user_id uuid,
  event_type text not null
    check (event_type in ('baseline', 'created', 'revoked', 'expired', 'renewed', 'updated')),
  reason text,
  before_state jsonb,
  after_state jsonb not null,
  occurred_at timestamptz not null default now(),
  check (reason is null or btrim(reason) <> '')
);

create index role_assignment_events_assignment_id_idx
  on public.role_assignment_events (assignment_id, occurred_at desc);

create index role_assignment_events_related_assignment_id_idx
  on public.role_assignment_events (related_assignment_id)
  where related_assignment_id is not null;

create index role_assignment_events_organization_id_idx
  on public.role_assignment_events
  ((after_state ->> 'organization_id'), occurred_at desc);

alter table public.role_assignment_events enable row level security;

create policy "Enterprise admins view role assignment events"
on public.role_assignment_events
for select
to authenticated
using (
  public.mac_is_platform_admin()
  or (
    (after_state ->> 'organization_id') is not null
    and public.mac_is_organization_admin(
      (after_state ->> 'organization_id')::uuid
    )
  )
);

revoke all on table public.role_assignment_events from public;
revoke all on table public.role_assignment_events from authenticated;
grant select on table public.role_assignment_events to authenticated;

insert into public.role_assignment_events (
  assignment_id,
  actor_user_id,
  event_type,
  reason,
  before_state,
  after_state,
  occurred_at
)
select
  id,
  null,
  'baseline',
  'Existing assignment captured when audit history was enabled.',
  null,
  to_jsonb(role_assignments),
  created_at
from public.role_assignments;

create or replace function public.mac_audit_role_assignment_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  audit_event_type text;
  audit_reason text;
  related_id uuid;
begin
  audit_event_type := nullif(
    current_setting('mac.audit_event_type', true),
    ''
  );
  audit_reason := nullif(
    btrim(current_setting('mac.audit_reason', true)),
    ''
  );
  related_id := nullif(
    current_setting('mac.audit_related_assignment_id', true),
    ''
  )::uuid;

  if audit_event_type is null or tg_op = 'UPDATE' then
    audit_event_type := case
      when tg_op = 'INSERT' then 'created'
      when new.status = 'revoked' and old.status is distinct from new.status
        then 'revoked'
      when new.status = 'expired' and old.status is distinct from new.status
        then 'expired'
      else 'updated'
    end;
  end if;

  insert into public.role_assignment_events (
    assignment_id,
    related_assignment_id,
    actor_user_id,
    event_type,
    reason,
    before_state,
    after_state
  ) values (
    new.id,
    related_id,
    auth.uid(),
    audit_event_type,
    audit_reason,
    case when tg_op = 'UPDATE' then to_jsonb(old) else null end,
    to_jsonb(new)
  );

  return new;
end;
$$;

revoke all
on function public.mac_audit_role_assignment_change()
from public;

create trigger role_assignments_audit_after_write
after insert or update on public.role_assignments
for each row
execute function public.mac_audit_role_assignment_change();

create or replace function public.mac_revoke_role_assignment(
  p_assignment_id uuid,
  p_reason text
)
returns public.role_assignments
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  updated_assignment public.role_assignments;
begin
  if nullif(btrim(p_reason), '') is null then
    raise exception 'A revocation reason is required.'
      using errcode = '22023';
  end if;

  perform set_config('mac.audit_reason', btrim(p_reason), true);
  perform set_config('mac.audit_event_type', 'revoked', true);

  update public.role_assignments
  set status = 'revoked'
  where id = p_assignment_id
    and status = 'active'
  returning * into updated_assignment;

  if updated_assignment.id is null then
    raise exception 'Only an active role assignment can be revoked.'
      using errcode = 'P0001';
  end if;

  return updated_assignment;
end;
$$;

create or replace function public.mac_expire_role_assignment(
  p_assignment_id uuid,
  p_reason text
)
returns public.role_assignments
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  updated_assignment public.role_assignments;
begin
  if nullif(btrim(p_reason), '') is null then
    raise exception 'An expiration reason is required.'
      using errcode = '22023';
  end if;

  perform set_config('mac.audit_reason', btrim(p_reason), true);
  perform set_config('mac.audit_event_type', 'expired', true);

  update public.role_assignments
  set status = 'expired', valid_until = least(coalesce(valid_until, now()), now())
  where id = p_assignment_id
    and status = 'active'
  returning * into updated_assignment;

  if updated_assignment.id is null then
    raise exception 'Only an active role assignment can be expired.'
      using errcode = 'P0001';
  end if;

  return updated_assignment;
end;
$$;

create or replace function public.mac_renew_role_assignment(
  p_assignment_id uuid,
  p_new_valid_until timestamptz,
  p_reason text
)
returns public.role_assignments
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  prior_assignment public.role_assignments;
  renewed_assignment public.role_assignments;
begin
  if nullif(btrim(p_reason), '') is null then
    raise exception 'A renewal reason is required.'
      using errcode = '22023';
  end if;

  if p_new_valid_until is not null and p_new_valid_until <= now() then
    raise exception 'A renewed assignment must expire in the future.'
      using errcode = '22023';
  end if;

  select * into prior_assignment
  from public.role_assignments
  where id = p_assignment_id
  for update;

  if prior_assignment.id is null then
    raise exception 'Role assignment not found.'
      using errcode = 'P0002';
  end if;

  if prior_assignment.status = 'active'
    and (
      prior_assignment.valid_until is null
      or prior_assignment.valid_until > now()
    )
  then
    raise exception 'An active, unexpired assignment cannot be renewed.'
      using errcode = 'P0001';
  end if;

  if prior_assignment.status not in ('active', 'expired', 'revoked') then
    raise exception 'This role assignment cannot be renewed.'
      using errcode = 'P0001';
  end if;

  if prior_assignment.status = 'active' then
    perform set_config('mac.audit_reason', btrim(p_reason), true);
    perform set_config('mac.audit_event_type', 'expired', true);

    update public.role_assignments
    set status = 'expired'
    where id = prior_assignment.id;
  end if;

  perform set_config('mac.audit_reason', btrim(p_reason), true);
  perform set_config('mac.audit_event_type', 'renewed', true);
  perform set_config(
    'mac.audit_related_assignment_id',
    prior_assignment.id::text,
    true
  );

  insert into public.role_assignments (
    organization_id,
    user_id,
    site_id,
    role_key,
    status,
    valid_from,
    valid_until
  ) values (
    prior_assignment.organization_id,
    prior_assignment.user_id,
    prior_assignment.site_id,
    prior_assignment.role_key,
    'active',
    now(),
    p_new_valid_until
  )
  returning * into renewed_assignment;

  return renewed_assignment;
end;
$$;

revoke all on function public.mac_revoke_role_assignment(uuid, text)
from public;
revoke all on function public.mac_expire_role_assignment(uuid, text)
from public;
revoke all on function public.mac_renew_role_assignment(uuid, timestamptz, text)
from public;

grant execute on function public.mac_revoke_role_assignment(uuid, text)
to authenticated;
grant execute on function public.mac_expire_role_assignment(uuid, text)
to authenticated;
grant execute on function public.mac_renew_role_assignment(uuid, timestamptz, text)
to authenticated;

comment on table public.role_assignment_events is
  'Append-only audit history for role assignment lifecycle changes.';

comment on function public.mac_revoke_role_assignment(uuid, text) is
  'Atomically revokes an active role assignment and records the actor and reason.';

comment on function public.mac_expire_role_assignment(uuid, text) is
  'Atomically expires an active role assignment and records the actor and reason.';

comment on function public.mac_renew_role_assignment(uuid, timestamptz, text) is
  'Creates a linked active replacement for an expired or revoked assignment while preserving the original.';
