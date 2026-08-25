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

create or replace function public.mac_validate_organization_configuration()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as '
declare
  locale_to_validate text;
  subtags text[];
  last_core_index integer;
  variant_index integer;
  subtag_index integer;
  extlang_count integer;
  has_duplicate_variants boolean;
begin
  if new.default_locale !~* ''^([a-z]{2,3}(-[a-z]{3}){0,3}|[a-z]{4}|[a-z]{5,8})(-[a-z]{4})?(-([a-z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*(-[0-9a-wy-z](-[a-z0-9]{2,8})+)*(-x(-[a-z0-9]{1,8})+)?$'' then
    raise exception ''default_locale must be a valid BCP 47 locale tag: %'', new.default_locale
      using errcode = ''22023'';
  end if;

  if (
    select count(*) <> count(distinct lower(extension_match[2]))
    from regexp_matches(new.default_locale, ''(^|-)([0-9a-wy-z])-'', ''gi'') as extension_match
  ) then
    raise exception ''default_locale must be a valid BCP 47 locale tag: %'', new.default_locale
      using errcode = ''22023'';
  end if;

  if exists (
    select 1
    from unnest(new.supported_locales) as supported_locale(locale)
    where locale !~* ''^([a-z]{2,3}(-[a-z]{3}){0,3}|[a-z]{4}|[a-z]{5,8})(-[a-z]{4})?(-([a-z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*(-[0-9a-wy-z](-[a-z0-9]{2,8})+)*(-x(-[a-z0-9]{1,8})+)?$''
  ) then
    raise exception ''supported_locales must contain only valid BCP 47 locale tags''
      using errcode = ''22023'';
  end if;

  foreach locale_to_validate in array array_prepend(new.default_locale, new.supported_locales)
  loop
    subtags := string_to_array(locale_to_validate, ''-'');
    last_core_index := cardinality(subtags);

    -- Extensions and private-use sequences begin with a singleton. Exclude
    -- them so repeated extension payloads are not treated as variants.
    if last_core_index >= 2 then
      for subtag_index in 2..last_core_index
      loop
        if char_length(subtags[subtag_index]) = 1 then
          last_core_index := subtag_index - 1;
          exit;
        end if;
      end loop;
    end if;

    variant_index := 2;

    -- Advance past the language, optional extlangs, script, and region. The
    -- remaining core subtags are variants because the shape check passed.
    if char_length(subtags[1]) between 2 and 3 then
      extlang_count := 0;

      while variant_index <= last_core_index
        and extlang_count < 3
        and subtags[variant_index] ~* ''^[a-z]{3}$''
      loop
        variant_index := variant_index + 1;
        extlang_count := extlang_count + 1;
      end loop;
    end if;

    if variant_index <= last_core_index
      and subtags[variant_index] ~* ''^[a-z]{4}$''
    then
      variant_index := variant_index + 1;
    end if;

    if variant_index <= last_core_index
      and subtags[variant_index] ~* ''^([a-z]{2}|[0-9]{3})$''
    then
      variant_index := variant_index + 1;
    end if;

    if variant_index <= last_core_index then
      select count(*) <> count(distinct lower(variant_subtag.value))
      into has_duplicate_variants
      from unnest(subtags[variant_index:last_core_index]) as variant_subtag(value);
    else
      has_duplicate_variants := false;
    end if;

    if has_duplicate_variants then
      if locale_to_validate = new.default_locale then
        raise exception ''default_locale must be a valid BCP 47 locale tag: %'', new.default_locale
          using errcode = ''22023'';
      end if;

      raise exception ''supported_locales must contain only valid BCP 47 locale tags''
        using errcode = ''22023'';
    end if;
  end loop;

  if exists (
    select 1
    from unnest(new.supported_locales) as supported_locale(locale)
    where (
      select count(*) <> count(distinct lower(extension_match[2]))
      from regexp_matches(supported_locale.locale, ''(^|-)([0-9a-wy-z])-'', ''gi'') as extension_match
    )
  ) then
    raise exception ''supported_locales must contain only valid BCP 47 locale tags''
      using errcode = ''22023'';
  end if;

  if not exists (
    select 1
    from pg_timezone_names
    where name = new.default_timezone
  ) or (
    new.default_timezone <> ''UTC''
    and new.default_timezone !~ ''^[A-Za-z]+(/[A-Za-z0-9_+/-]+)+$''
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
before insert or update of default_timezone, default_locale, supported_locales
on public.organization_configurations
for each row
execute function public.mac_validate_organization_configuration();

create or replace function public.mac_seed_organization_configuration()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
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

revoke insert, delete
on table public.organization_configurations
from authenticated;

revoke all on function public.mac_seed_organization_configuration()
from public, anon, authenticated;

revoke all on function public.mac_validate_organization_configuration()
from public, anon, authenticated;
