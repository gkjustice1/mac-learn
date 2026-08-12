-- ============================================================
-- MAC Learn: current-user authorization context
-- ============================================================

create or replace function public.mac_current_user_roles()
returns table (
  role_key text,
  organization_id uuid,
  site_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ra.role_key,
    ra.organization_id,
    ra.site_id
  from public.role_assignments ra
  join public.users u
    on u.id = ra.user_id
  where ra.user_id = auth.uid()
    and u.account_status = 'active'
    and ra.status = 'active'
    and ra.valid_from <= now()
    and (
      ra.valid_until is null
      or ra.valid_until > now()
    )
  order by
    case ra.role_key
      when 'platform_admin' then 1
      when 'platform_support' then 2
      when 'organization_admin' then 3
      when 'site_admin' then 4
      when 'academic_lead' then 5
      when 'teacher' then 6
      when 'tutor' then 7
      when 'guardian' then 8
      when 'student' then 9
      else 100
    end,
    ra.organization_id nulls first,
    ra.site_id nulls first;
$$;

revoke all on function public.mac_current_user_roles()
from public;

grant execute on function public.mac_current_user_roles()
to authenticated;