-- Approved direction: retire unused legacy access; deployment requires separate authorization.
-- Refuse retirement if provisioning has introduced an unmigrated identity.
do $$
begin
  if exists (
    select 1 from public.profiles p
    where not exists (select 1 from public.users u where u.id = p.user_id)
  ) then
    raise exception 'Legacy retirement blocked: profiles without enterprise identity remain';
  end if;
end;
$$;

drop policy if exists "Legacy admins manage students during transition" on public.students;
drop policy if exists "Legacy admins manage tutors during transition" on public.tutor_profiles;
drop policy if exists "Legacy admins manage sessions during transition" on public.sessions;
drop policy if exists "Authenticated families view only related students" on public.students;
create policy "Authenticated families view only related students"
on public.students for select to authenticated
using (public.mac_family_can_access_student(id));

create or replace function public.mac_can_manage_tutor_profile(
  requested_tutor_id uuid,
  requested_organization_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $tutor_admin$
  select exists (
    select 1
    from public.tutor_profiles tutor
    where tutor.id = requested_tutor_id
      and (
        public.mac_is_platform_admin()
        or (
          tutor.organization_id is not null
          and public.mac_is_organization_admin(tutor.organization_id)
          and (
            requested_organization_id is null
            or requested_organization_id = tutor.organization_id
          )
        )
        or (
          tutor.organization_id is null
          and requested_organization_id is not null
          and public.mac_is_organization_admin(requested_organization_id)
        )
      )
  );
$tutor_admin$;

-- RESTRICT (the default) prevents silently removing unknown dependent objects.
drop function public.mac_can_use_legacy_admin_access();
drop function public.mac_can_use_legacy_family_link(uuid);
