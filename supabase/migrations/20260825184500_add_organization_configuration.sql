-- ============================================================
-- MAC LEARN
-- Organization configuration seed and administration
-- ============================================================

create table if not exists public.organization_configurations (
  organization_id uuid primary key
    references public.organizations(id)
    on delete cascade,

  default_timezone text not null default 'America/New_York',
  default_locale text not null default 'en-US',
  supported_locales text[] not null default array['en-US', 'es-US', 'ht-HT']::text[],
  academic_year_start_month smallint not null default 8
    check (academic_year_start_month between 1 and 12),
  attendance_required boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (cardinality(supported_locales) > 0),
  check (default_locale = any (supported_locales))
);

comment on table public.organization_configurations is
  'One operational-default configuration record per MAC Learn organization.';

comment on column public.organization_configurations.default_timezone is
  'IANA timezone used by the organization unless a site specifies its own timezone.';

drop trigger if exists organization_configurations_mac_set_updated_at
on public.organization_configurations;

create trigger organization_configurations_mac_set_updated_at
before update on public.organization_configurations
for each row
execute function public.mac_set_updated_at();

create or replace function public.mac_validate_organization_configuration_timezone()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as '
begin
  if not exists (
    select 1
    from pg_timezone_names
    where name = new.default_timezone
  ) then
    raise exception ''default_timezone must be a valid IANA timezone: %'', new.default_timezone
      using errcode = ''22023'';
  end if;

  return new;
end;
';

drop trigger if exists organization_configurations_validate_timezone
on public.organization_configurations;

create trigger organization_configurations_validate_timezone
before insert or update of default_timezone on public.organization_configurations
for each row
execute function public.mac_validate_organization_configuration_timezone();

create or replace function public.mac_seed_organization_configuration()
returns trigger
language plpgsql
security invoker
set search_path = public
as '
begin
  insert into public.organization_configurations (organization_id)
  values (new.id)
  on conflict (organization_id) do nothing;

  return new;
end;
';

drop trigger if exists organizations_seed_configuration
on public.organizations;

create trigger organizations_seed_configuration
after insert on public.organizations
for each row
execute function public.mac_seed_organization_configuration();

-- Reconcile organizations created before this migration. The conflict clause
-- makes the migration safe to re-run during local resets and deployments.
insert into public.organization_configurations (organization_id)
select id
from public.organizations
on conflict (organization_id) do nothing;

alter table public.organization_configurations enable row level security;

drop policy if exists
  "Organization admins view organization configuration"
on public.organization_configurations;

create policy
  "Organization admins view organization configuration"
on public.organization_configurations
for select
to authenticated
using (
  (select public.mac_is_organization_admin(organization_id))
);

drop policy if exists
  "Platform admins view organization configuration"
on public.organization_configurations;

create policy
  "Platform admins view organization configuration"
on public.organization_configurations
for select
to authenticated
using ((select public.mac_is_platform_admin()));

drop policy if exists
  "Platform admins update organization configuration"
on public.organization_configurations;

create policy
  "Platform admins update organization configuration"
on public.organization_configurations
for update
to authenticated
using ((select public.mac_is_platform_admin()))
with check ((select public.mac_is_platform_admin()));

grant select, update
on table public.organization_configurations
to authenticated;

revoke all on function public.mac_seed_organization_configuration()
from public, anon, authenticated;

revoke all on function public.mac_validate_organization_configuration_timezone()
from public, anon, authenticated;
