-- MAC Learn: complete elapsed sessions atomically when a Tutor saves attendance.

create table public.session_status_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null
    references public.sessions(id) on delete restrict,
  actor_user_id uuid,
  event_type text not null
    check (event_type in ('baseline', 'status_changed')),
  from_status public.session_status,
  to_status public.session_status,
  reason text not null
    check (btrim(reason) <> ''),
  occurred_at timestamptz not null default now()
);

create index session_status_events_session_id_idx
  on public.session_status_events (session_id, occurred_at desc);

alter table public.session_status_events enable row level security;

create policy "Authorized staff view session status events"
on public.session_status_events
for select
to authenticated
using (
  public.mac_is_platform_admin()
  or exists (
    select 1
    from public.sessions session
    where session.id = session_status_events.session_id
      and session.tutor_id = public.mac_current_tutor_id()
  )
);

revoke all on table public.session_status_events from public, anon, authenticated;
grant select on table public.session_status_events to authenticated;

insert into public.session_status_events (
  session_id,
  actor_user_id,
  event_type,
  from_status,
  to_status,
  reason,
  occurred_at
)
select
  session.id,
  null,
  'baseline',
  null,
  session.status,
  'Existing session captured when lifecycle audit was enabled.',
  coalesce(session.created_at, now())
from public.sessions session;

create or replace function public.mac_audit_session_status_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $audit$
declare
  audit_reason text;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  audit_reason := nullif(
    btrim(current_setting('mac.session_status_reason', true)),
    ''
  );

  insert into public.session_status_events (
    session_id,
    actor_user_id,
    event_type,
    from_status,
    to_status,
    reason
  ) values (
    new.id,
    (select auth.uid()),
    'status_changed',
    old.status,
    new.status,
    coalesce(audit_reason, 'Session status updated.')
  );

  return new;
end;
$audit$;

revoke all on function public.mac_audit_session_status_change()
from public, anon, authenticated;

drop trigger if exists sessions_audit_status_after_update
on public.sessions;
create trigger sessions_audit_status_after_update
after update of status on public.sessions
for each row
when (old.status is distinct from new.status)
execute function public.mac_audit_session_status_change();

create or replace function public.mac_complete_elapsed_session_from_note()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $complete$
begin
  perform set_config(
    'mac.session_status_reason',
    'Elapsed session completed when Tutor attendance note was saved.',
    true
  );

  update public.sessions session
  set status = 'completed'
  where session.id = new.session_id
    and session.tutor_id = new.tutor_id
    and session.end_time <= now()
    and session.status in ('pending', 'confirmed');

  return new;
end;
$complete$;

revoke all on function public.mac_complete_elapsed_session_from_note()
from public, anon, authenticated;

drop trigger if exists session_notes_complete_elapsed_session_after_insert
on public.session_notes;
create trigger session_notes_complete_elapsed_session_after_insert
after insert on public.session_notes
for each row
execute function public.mac_complete_elapsed_session_from_note();

select set_config(
  'mac.session_status_reason',
  'Existing elapsed session completed from its saved attendance note.',
  true
);

update public.sessions session
set status = 'completed'
where session.end_time <= now()
  and session.status in ('pending', 'confirmed')
  and exists (
    select 1
    from public.session_notes note
    where note.session_id = session.id
      and note.tutor_id = session.tutor_id
  );

comment on table public.session_status_events is
  'Append-only audit history for session lifecycle status changes.';

comment on function public.mac_complete_elapsed_session_from_note() is
  'Atomically completes an elapsed pending or confirmed session after its assigned Tutor saves attendance.';
