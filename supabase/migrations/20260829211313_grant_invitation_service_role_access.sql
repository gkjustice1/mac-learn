-- MAC Learn: expose only the two invitation operations needed by the server.
-- service_role receives no direct table access to enterprise identity data.
revoke select, insert, update, delete
on table public.people, public.users, public.profiles
from service_role;

create or replace function public.mac_create_invited_enterprise_identity(
  p_user_id uuid, p_first_name text, p_last_name text, p_email text,
  p_organization_id uuid, p_site_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  created_person_id uuid;
begin
  if not exists (
    select 1 from auth.users as auth_user
    where auth_user.id = p_user_id
      and lower(auth_user.email) = lower(p_email)
  ) then
    raise exception 'Invitation auth user does not match the requested identity';
  end if;

  insert into public.people (first_name, last_name, primary_email)
  values (p_first_name, p_last_name, lower(p_email))
  returning id into created_person_id;

  insert into public.users (id, person_id, account_status)
  values (p_user_id, created_person_id, 'invited');

  insert into public.profiles (
    user_id, full_name, email, organization_id, site_id, person_id, enterprise_user_id
  ) values (
    p_user_id, trim(p_first_name || ' ' || p_last_name), lower(p_email),
    p_organization_id, p_site_id, created_person_id, p_user_id
  );

  return created_person_id;
end;
$$;

create or replace function public.mac_cleanup_invited_enterprise_identity(
  p_user_id uuid
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  cleanup_person_id uuid;
  cleanup_account_status text;
begin
  select enterprise_user.person_id, enterprise_user.account_status
  into cleanup_person_id, cleanup_account_status
  from public.users as enterprise_user
  where enterprise_user.id = p_user_id
  for update;

  if not found then
    return 'missing';
  end if;

  if cleanup_account_status <> 'invited' or cleanup_person_id is null then
    return 'not_invited';
  end if;

  delete from public.role_assignment_events as assignment_event
  where assignment_event.assignment_id in (
      select assignment.id
      from public.role_assignments as assignment
      where assignment.user_id = p_user_id
    )
    or assignment_event.related_assignment_id in (
      select assignment.id
      from public.role_assignments as assignment
      where assignment.user_id = p_user_id
    );

  delete from public.role_assignments
  where user_id = p_user_id;

  delete from public.profiles
  where user_id = p_user_id
    and person_id = cleanup_person_id
    and enterprise_user_id = p_user_id;

  delete from public.users
  where id = p_user_id
    and person_id = cleanup_person_id
    and account_status = 'invited';

  delete from public.people where id = cleanup_person_id;
  return 'cleaned';
end;
$$;

revoke all on function public.mac_create_invited_enterprise_identity(uuid, text, text, text, uuid, uuid)
from public, anon, authenticated;
revoke all on function public.mac_cleanup_invited_enterprise_identity(uuid)
from public, anon, authenticated;

grant execute on function public.mac_create_invited_enterprise_identity(uuid, text, text, text, uuid, uuid)
to service_role;
grant execute on function public.mac_cleanup_invited_enterprise_identity(uuid)
to service_role;
