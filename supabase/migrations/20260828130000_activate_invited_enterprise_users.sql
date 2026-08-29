-- MAC Learn: activate an invitation only after authenticated sign-in.
create or replace function public.mac_activate_invited_enterprise_user()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return false;
  end if;

  update public.users
  set account_status = 'active'
  where id = auth.uid()
    and account_status = 'invited';

  return found;
end;
$$;

revoke all on function public.mac_activate_invited_enterprise_user() from public;
grant execute on function public.mac_activate_invited_enterprise_user() to authenticated;
