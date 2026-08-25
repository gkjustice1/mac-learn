-- Keep renewal linkage on the replacement INSERT only. A nested
-- conflict-expiration UPDATE may run before that INSERT and must
-- not inherit the replacement's related assignment identifier.

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

  if tg_op = 'INSERT' then
    related_id := nullif(
      current_setting('mac.audit_related_assignment_id', true),
      ''
    )::uuid;
  else
    related_id := null;
  end if;

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

comment on function public.mac_audit_role_assignment_change() is
  'Records append-only assignment events and applies renewal linkage only to the inserted replacement.';
