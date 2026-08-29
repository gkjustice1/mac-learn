-- MAC Learn: keep active Tutor role assignments linked to tutor_profiles.

create or replace function public.mac_sync_tutor_profile_from_assignment()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.role_key = 'tutor' and new.status = 'active' then
    insert into public.tutor_profiles (
      user_id,
      organization_id,
      site_id,
      person_id
    )
    select
      profile.id,
      new.organization_id,
      new.site_id,
      profile.person_id
    from public.profiles as profile
    where profile.user_id = new.user_id
    on conflict (user_id) do update
    set organization_id = excluded.organization_id,
        site_id = excluded.site_id,
        person_id = excluded.person_id;
  end if;

  return new;
end;
$$;

revoke all on function public.mac_sync_tutor_profile_from_assignment()
from public, anon, authenticated, service_role;

drop trigger if exists role_assignments_sync_tutor_profile
on public.role_assignments;

create trigger role_assignments_sync_tutor_profile
after insert or update of role_key, status, organization_id, site_id
on public.role_assignments
for each row
execute function public.mac_sync_tutor_profile_from_assignment();

drop policy if exists "Tutors view assigned organizations"
on public.organizations;
create policy "Tutors view assigned organizations"
on public.organizations
for select
to authenticated
using (public.mac_has_role('tutor', id, null));

drop policy if exists "Tutors view assigned sites"
on public.sites;
create policy "Tutors view assigned sites"
on public.sites
for select
to authenticated
using (public.mac_has_role('tutor', organization_id, id));

insert into public.tutor_profiles (
  user_id,
  organization_id,
  site_id,
  person_id
)
select distinct on (profile.id)
  profile.id,
  assignment.organization_id,
  assignment.site_id,
  profile.person_id
from public.role_assignments as assignment
join public.profiles as profile
  on profile.user_id = assignment.user_id
where assignment.role_key = 'tutor'
  and assignment.status = 'active'
order by
  profile.id,
  assignment.site_id nulls first,
  assignment.created_at desc
on conflict (user_id) do update
set organization_id = excluded.organization_id,
    site_id = excluded.site_id,
    person_id = excluded.person_id;
