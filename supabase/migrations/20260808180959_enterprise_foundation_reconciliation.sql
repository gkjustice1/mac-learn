-- ============================================================
-- MAC LEARN
-- Enterprise Foundation Reconciliation
--
-- Purpose:
-- Add the new enterprise identity / organization foundation
-- around the existing MAC LEARN MVP schema without replacing
-- or recreating existing MVP tables.
--
-- Existing MVP tables are preserved.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Shared MAC updated_at trigger function
-- ------------------------------------------------------------

create or replace function public.mac_set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ------------------------------------------------------------
-- 2. Organizations
-- Top-level tenant / institutional boundary
-- ------------------------------------------------------------

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  slug text not null unique,

  status text not null default 'active'
    check (status in ('active', 'inactive', 'suspended')),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists organizations_mac_set_updated_at
on public.organizations;

create trigger organizations_mac_set_updated_at
before update on public.organizations
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 3. Sites
-- Campuses, centers, branches, or other operating locations
-- ------------------------------------------------------------

create table if not exists public.sites (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete cascade,

  name text not null,
  code text,

  status text not null default 'active'
    check (
      status in (
        'active',
        'inactive',
        'planned',
        'closed'
      )
    ),

  timezone text not null default 'America/New_York',

  address_line_1 text,
  address_line_2 text,
  city text,
  state_region text,
  postal_code text,
  country_code text not null default 'US',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (organization_id, code)
);

create index if not exists sites_organization_id_idx
  on public.sites(organization_id);

drop trigger if exists sites_mac_set_updated_at
on public.sites;

create trigger sites_mac_set_updated_at
before update on public.sites
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 4. People
-- Canonical human identity
--
-- A person may later be associated with:
-- - authenticated user
-- - student
-- - guardian
-- - staff
-- - tutor
-- ------------------------------------------------------------

create table if not exists public.people (
  id uuid primary key default gen_random_uuid(),

  first_name text not null,
  middle_name text,
  last_name text not null,
  preferred_name text,

  date_of_birth date,

  primary_email text,
  primary_phone text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists people_name_idx
  on public.people(last_name, first_name);

create index if not exists people_primary_email_idx
  on public.people(primary_email);

drop trigger if exists people_mac_set_updated_at
on public.people;

create trigger people_mac_set_updated_at
before update on public.people
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 5. Users
-- MAC application identity mapped to Supabase auth.users
--
-- Existing public.profiles is preserved.
-- public.users becomes the future enterprise identity bridge.
-- ------------------------------------------------------------

create table if not exists public.users (
  id uuid primary key
    references auth.users(id)
    on delete cascade,

  person_id uuid
    references public.people(id)
    on delete set null,

  account_status text not null default 'active'
    check (
      account_status in (
        'invited',
        'active',
        'disabled',
        'locked',
        'archived'
      )
    ),

  last_seen_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (person_id)
);

create index if not exists users_person_id_idx
  on public.users(person_id);

drop trigger if exists users_mac_set_updated_at
on public.users;

create trigger users_mac_set_updated_at
before update on public.users
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 6. Guardians
-- Enterprise guardian/family participant
-- ------------------------------------------------------------

create table if not exists public.guardians (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete restrict,

  person_id uuid not null
    references public.people(id)
    on delete restrict,

  status text not null default 'active'
    check (
      status in (
        'active',
        'inactive',
        'restricted',
        'archived'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (organization_id, person_id)
);

create index if not exists guardians_organization_id_idx
  on public.guardians(organization_id);

create index if not exists guardians_person_id_idx
  on public.guardians(person_id);

drop trigger if exists guardians_mac_set_updated_at
on public.guardians;

create trigger guardians_mac_set_updated_at
before update on public.guardians
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 7. Guardian <-> Student Relationships
--
-- This replaces the long-term assumption that a learner has
-- only one parent/guardian.
--
-- Existing students.parent_id remains untouched for now.
-- ------------------------------------------------------------

create table if not exists public.guardian_student_relationships (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete restrict,

  guardian_id uuid not null
    references public.guardians(id)
    on delete cascade,

  student_id uuid not null
    references public.students(id)
    on delete cascade,

  relationship_type text not null,

  educational_access boolean not null default true,
  pickup_authorized boolean not null default false,
  emergency_contact boolean not null default false,
  custody_access boolean not null default false,

  contact_priority integer
    check (
      contact_priority is null
      or contact_priority >= 1
    ),

  valid_from date,
  valid_until date,

  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (guardian_id, student_id)
);

create index if not exists guardian_student_relationships_org_idx
  on public.guardian_student_relationships(organization_id);

create index if not exists guardian_student_relationships_guardian_idx
  on public.guardian_student_relationships(guardian_id);

create index if not exists guardian_student_relationships_student_idx
  on public.guardian_student_relationships(student_id);

drop trigger if exists guardian_student_relationships_mac_set_updated_at
on public.guardian_student_relationships;

create trigger guardian_student_relationships_mac_set_updated_at
before update on public.guardian_student_relationships
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 8. Staff
-- Employees, tutors, instructors, administrators,
-- contractors, and volunteers
-- ------------------------------------------------------------

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null
    references public.organizations(id)
    on delete restrict,

  person_id uuid not null
    references public.people(id)
    on delete restrict,

  primary_site_id uuid
    references public.sites(id)
    on delete set null,

  employee_id text,

  staff_type text not null default 'staff'
    check (
      staff_type in (
        'staff',
        'tutor',
        'teacher',
        'administrator',
        'contractor',
        'volunteer'
      )
    ),

  status text not null default 'active'
    check (
      status in (
        'active',
        'inactive',
        'leave',
        'terminated',
        'archived'
      )
    ),

  start_date date,
  end_date date,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (organization_id, person_id),
  unique (organization_id, employee_id)
);

create index if not exists staff_organization_id_idx
  on public.staff(organization_id);

create index if not exists staff_primary_site_id_idx
  on public.staff(primary_site_id);

create index if not exists staff_person_id_idx
  on public.staff(person_id);

drop trigger if exists staff_mac_set_updated_at
on public.staff;

create trigger staff_mac_set_updated_at
before update on public.staff
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 9. Role Assignments
-- Organization/site-scoped authorization
-- ------------------------------------------------------------

create table if not exists public.role_assignments (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid
    references public.organizations(id)
    on delete cascade,

  user_id uuid not null
    references public.users(id)
    on delete cascade,

  site_id uuid
    references public.sites(id)
    on delete cascade,

  role_key text not null
    check (
      role_key in (
        'student',
        'guardian',
        'tutor',
        'teacher',
        'academic_lead',
        'site_admin',
        'organization_admin',
        'platform_support',
        'platform_admin'
      )
    ),

  status text not null default 'active'
    check (
      status in (
        'active',
        'inactive',
        'expired',
        'revoked'
      )
    ),

  valid_from timestamptz not null default now(),
  valid_until timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists role_assignments_user_id_idx
  on public.role_assignments(user_id);

create index if not exists role_assignments_organization_id_idx
  on public.role_assignments(organization_id);

create index if not exists role_assignments_site_id_idx
  on public.role_assignments(site_id);

create index if not exists role_assignments_role_key_idx
  on public.role_assignments(role_key);

drop trigger if exists role_assignments_mac_set_updated_at
on public.role_assignments;

create trigger role_assignments_mac_set_updated_at
before update on public.role_assignments
for each row
execute function public.mac_set_updated_at();


-- ------------------------------------------------------------
-- 10. Safely extend existing MVP profiles
--
-- Existing profile functionality is preserved.
-- These nullable references allow gradual migration.
-- ------------------------------------------------------------

alter table public.profiles
  add column if not exists organization_id uuid;

alter table public.profiles
  add column if not exists site_id uuid;

alter table public.profiles
  add column if not exists person_id uuid;

alter table public.profiles
  add column if not exists enterprise_user_id uuid;

create index if not exists profiles_organization_id_idx
  on public.profiles(organization_id);

create index if not exists profiles_site_id_idx
  on public.profiles(site_id);

create index if not exists profiles_person_id_idx
  on public.profiles(person_id);

create index if not exists profiles_enterprise_user_id_idx
  on public.profiles(enterprise_user_id);


-- ------------------------------------------------------------
-- 11. Safely extend existing MVP students
--
-- Do not remove existing parent_id or academic fields yet.
-- ------------------------------------------------------------

alter table public.students
  add column if not exists organization_id uuid;

alter table public.students
  add column if not exists person_id uuid;

alter table public.students
  add column if not exists primary_site_id uuid;

alter table public.students
  add column if not exists external_student_id text;

alter table public.students
  add column if not exists enterprise_status text default 'active';

alter table public.students
  add column if not exists enrollment_start_date date;

alter table public.students
  add column if not exists enrollment_end_date date;

create index if not exists students_organization_id_idx
  on public.students(organization_id);

create index if not exists students_person_id_idx
  on public.students(person_id);

create index if not exists students_primary_site_id_idx
  on public.students(primary_site_id);


-- ------------------------------------------------------------
-- 12. Safely extend existing MVP tutor profiles
-- ------------------------------------------------------------

alter table public.tutor_profiles
  add column if not exists organization_id uuid;

alter table public.tutor_profiles
  add column if not exists site_id uuid;

alter table public.tutor_profiles
  add column if not exists person_id uuid;

alter table public.tutor_profiles
  add column if not exists staff_id uuid;

create index if not exists tutor_profiles_organization_id_idx
  on public.tutor_profiles(organization_id);

create index if not exists tutor_profiles_site_id_idx
  on public.tutor_profiles(site_id);

create index if not exists tutor_profiles_person_id_idx
  on public.tutor_profiles(person_id);

create index if not exists tutor_profiles_staff_id_idx
  on public.tutor_profiles(staff_id);


-- ------------------------------------------------------------
-- 13. Add foreign-key constraints to legacy tables
--
-- Added only after the new enterprise tables exist.
-- Existing legacy columns remain nullable.
-- ------------------------------------------------------------

alter table public.profiles
  drop constraint if exists profiles_organization_id_fkey;

alter table public.profiles
  add constraint profiles_organization_id_fkey
  foreign key (organization_id)
  references public.organizations(id)
  on delete set null
  not valid;

alter table public.profiles
  drop constraint if exists profiles_site_id_fkey;

alter table public.profiles
  add constraint profiles_site_id_fkey
  foreign key (site_id)
  references public.sites(id)
  on delete set null
  not valid;

alter table public.profiles
  drop constraint if exists profiles_person_id_fkey;

alter table public.profiles
  add constraint profiles_person_id_fkey
  foreign key (person_id)
  references public.people(id)
  on delete set null
  not valid;

alter table public.profiles
  drop constraint if exists profiles_enterprise_user_id_fkey;

alter table public.profiles
  add constraint profiles_enterprise_user_id_fkey
  foreign key (enterprise_user_id)
  references public.users(id)
  on delete set null
  not valid;


alter table public.students
  drop constraint if exists students_organization_id_fkey;

alter table public.students
  add constraint students_organization_id_fkey
  foreign key (organization_id)
  references public.organizations(id)
  on delete restrict
  not valid;

alter table public.students
  drop constraint if exists students_person_id_fkey;

alter table public.students
  add constraint students_person_id_fkey
  foreign key (person_id)
  references public.people(id)
  on delete restrict
  not valid;

alter table public.students
  drop constraint if exists students_primary_site_id_fkey;

alter table public.students
  add constraint students_primary_site_id_fkey
  foreign key (primary_site_id)
  references public.sites(id)
  on delete set null
  not valid;


alter table public.tutor_profiles
  drop constraint if exists tutor_profiles_organization_id_fkey;

alter table public.tutor_profiles
  add constraint tutor_profiles_organization_id_fkey
  foreign key (organization_id)
  references public.organizations(id)
  on delete restrict
  not valid;

alter table public.tutor_profiles
  drop constraint if exists tutor_profiles_site_id_fkey;

alter table public.tutor_profiles
  add constraint tutor_profiles_site_id_fkey
  foreign key (site_id)
  references public.sites(id)
  on delete set null
  not valid;

alter table public.tutor_profiles
  drop constraint if exists tutor_profiles_person_id_fkey;

alter table public.tutor_profiles
  add constraint tutor_profiles_person_id_fkey
  foreign key (person_id)
  references public.people(id)
  on delete restrict
  not valid;

alter table public.tutor_profiles
  drop constraint if exists tutor_profiles_staff_id_fkey;

alter table public.tutor_profiles
  add constraint tutor_profiles_staff_id_fkey
  foreign key (staff_id)
  references public.staff(id)
  on delete set null
  not valid;


-- ------------------------------------------------------------
-- 14. Row Level Security
--
-- Enterprise tables start default-deny.
-- Policies will be added in a separate security migration.
-- ------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.sites enable row level security;
alter table public.people enable row level security;
alter table public.users enable row level security;
alter table public.guardians enable row level security;
alter table public.guardian_student_relationships enable row level security;
alter table public.staff enable row level security;
alter table public.role_assignments enable row level security;


-- ------------------------------------------------------------
-- 15. Documentation
-- ------------------------------------------------------------

comment on table public.organizations is
  'MAC LEARN tenant and institutional organization records.';

comment on table public.sites is
  'MAC LEARN campuses, centers, branches, and operating sites.';

comment on table public.people is
  'Canonical human identity used across learner, guardian, staff, tutor, and user domains.';

comment on table public.users is
  'MAC LEARN enterprise application identities linked to Supabase auth.users.';

comment on table public.guardians is
  'Enterprise guardian and family participant records.';

comment on table public.guardian_student_relationships is
  'Verified guardian-to-student relationships including education, pickup, emergency, and custody attributes.';

comment on table public.staff is
  'MAC LEARN workforce records including tutors, teachers, administrators, contractors, and volunteers.';

comment on table public.role_assignments is
  'Organization- and site-scoped authorization roles assigned to MAC LEARN users.';

comment on column public.students.organization_id is
  'Enterprise organization scope added during MAC LEARN architecture reconciliation.';

comment on column public.students.person_id is
  'Optional canonical person link during legacy-to-enterprise migration.';

comment on column public.profiles.enterprise_user_id is
  'Bridge between the legacy MAC LEARN profile and enterprise user identity.';