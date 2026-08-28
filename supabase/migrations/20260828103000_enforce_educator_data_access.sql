-- MAC Learn: educator classroom data access
--
-- Establishes the minimum instructional relationship model required to
-- authorize an educator's access to classrooms, enrolled students, and
-- instructional records.  All access is tenant-scoped and relationship-based.

create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  site_id uuid,
  name text not null,
  code text,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, code),
  foreign key (organization_id, site_id)
    references public.sites(organization_id, id) on delete restrict
);

create table if not exists public.classroom_educators (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  classroom_id uuid not null,
  user_id uuid not null references public.users(id) on delete cascade,
  assignment_role text not null default 'teacher'
    check (assignment_role in ('teacher', 'co_teacher', 'academic_lead')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  assigned_from date not null default current_date,
  assigned_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (classroom_id, user_id),
  foreign key (organization_id, classroom_id)
    references public.classrooms(organization_id, id) on delete cascade,
  check (assigned_until is null or assigned_until >= assigned_from)
);

create table if not exists public.classroom_student_enrollments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  classroom_id uuid not null,
  student_id uuid not null,
  status text not null default 'active' check (status in ('active', 'inactive', 'withdrawn')),
  enrolled_from date not null default current_date,
  enrolled_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, classroom_id, student_id),
  foreign key (organization_id, classroom_id)
    references public.classrooms(organization_id, id) on delete cascade,
  foreign key (organization_id, student_id)
    references public.students(organization_id, id) on delete cascade,
  check (enrolled_until is null or enrolled_until >= enrolled_from)
);

create table if not exists public.educator_instructional_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  classroom_id uuid not null,
  student_id uuid not null,
  educator_user_id uuid not null references public.users(id) on delete restrict,
  record_type text not null check (record_type in ('observation', 'instruction', 'intervention', 'assessment_note')),
  content text not null,
  occurred_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, classroom_id, student_id)
    references public.classroom_student_enrollments(organization_id, classroom_id, student_id)
    on delete restrict
);

create index if not exists classrooms_organization_id_idx on public.classrooms(organization_id);
create index if not exists classroom_educators_user_id_idx on public.classroom_educators(user_id);
create index if not exists classroom_student_enrollments_student_id_idx on public.classroom_student_enrollments(student_id);
create index if not exists educator_instructional_records_educator_user_id_idx on public.educator_instructional_records(educator_user_id);

drop trigger if exists classrooms_mac_set_updated_at on public.classrooms;
create trigger classrooms_mac_set_updated_at before update on public.classrooms
for each row execute function public.mac_set_updated_at();

drop trigger if exists classroom_educators_mac_set_updated_at on public.classroom_educators;
create trigger classroom_educators_mac_set_updated_at before update on public.classroom_educators
for each row execute function public.mac_set_updated_at();

drop trigger if exists classroom_student_enrollments_mac_set_updated_at on public.classroom_student_enrollments;
create trigger classroom_student_enrollments_mac_set_updated_at before update on public.classroom_student_enrollments
for each row execute function public.mac_set_updated_at();

drop trigger if exists educator_instructional_records_mac_set_updated_at on public.educator_instructional_records;
create trigger educator_instructional_records_mac_set_updated_at before update on public.educator_instructional_records
for each row execute function public.mac_set_updated_at();

create or replace function public.mac_is_active_classroom_educator(
  requested_classroom_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classroom_educators assignment
    join public.classrooms classroom on classroom.id = assignment.classroom_id
    join public.users enterprise_user on enterprise_user.id = assignment.user_id
    join public.role_assignments role_assignment on role_assignment.user_id = assignment.user_id
    where assignment.classroom_id = requested_classroom_id
      and assignment.user_id = auth.uid()
      and classroom.status = 'active'
      and assignment.status = 'active'
      and assignment.assigned_from <= current_date
      and (assignment.assigned_until is null or assignment.assigned_until >= current_date)
      and enterprise_user.account_status = 'active'
      and role_assignment.status = 'active'
      and role_assignment.valid_from <= now()
      and (role_assignment.valid_until is null or role_assignment.valid_until > now())
      and role_assignment.role_key in ('teacher', 'academic_lead')
      and role_assignment.organization_id = classroom.organization_id
      and (role_assignment.site_id is null or role_assignment.site_id = classroom.site_id)
  );
$$;

create or replace function public.mac_educator_can_access_student(
  requested_classroom_id uuid,
  requested_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.mac_is_active_classroom_educator(requested_classroom_id)
    and exists (
      select 1
      from public.classroom_student_enrollments enrollment
      where enrollment.classroom_id = requested_classroom_id
        and enrollment.student_id = requested_student_id
        and enrollment.status = 'active'
        and enrollment.enrolled_from <= current_date
        and (enrollment.enrolled_until is null or enrollment.enrolled_until >= current_date)
    );
$$;

revoke all on function public.mac_is_active_classroom_educator(uuid) from public;
grant execute on function public.mac_is_active_classroom_educator(uuid) to authenticated;
revoke all on function public.mac_educator_can_access_student(uuid, uuid) from public;
grant execute on function public.mac_educator_can_access_student(uuid, uuid) to authenticated;

alter table public.classrooms enable row level security;
alter table public.classroom_educators enable row level security;
alter table public.classroom_student_enrollments enable row level security;
alter table public.educator_instructional_records enable row level security;

grant select, insert, update, delete
on public.classrooms, public.classroom_educators, public.classroom_student_enrollments,
  public.educator_instructional_records
to authenticated;

create policy "Educators view assigned classrooms" on public.classrooms for select to authenticated
using (public.mac_is_active_classroom_educator(id));

create policy "Educators view own classroom assignments" on public.classroom_educators for select to authenticated
using (user_id = (select auth.uid()));

create policy "Educators view students in assigned classrooms" on public.classroom_student_enrollments for select to authenticated
using (public.mac_educator_can_access_student(classroom_id, student_id));

create policy "Educators view assigned students" on public.students for select to authenticated
using (exists (
  select 1 from public.classroom_student_enrollments enrollment
  where enrollment.student_id = students.id
    and enrollment.organization_id = students.organization_id
    and public.mac_educator_can_access_student(enrollment.classroom_id, students.id)
));

create policy "Educators view instructional records for assigned students" on public.educator_instructional_records for select to authenticated
using (public.mac_educator_can_access_student(classroom_id, student_id));

create policy "Educators create own instructional records for assigned students" on public.educator_instructional_records for insert to authenticated
with check (
  educator_user_id = (select auth.uid())
  and public.mac_educator_can_access_student(classroom_id, student_id)
);

create policy "Educators update own instructional records" on public.educator_instructional_records for update to authenticated
using (educator_user_id = (select auth.uid()) and public.mac_educator_can_access_student(classroom_id, student_id))
with check (educator_user_id = (select auth.uid()) and public.mac_educator_can_access_student(classroom_id, student_id));

create policy "Enterprise admins manage classrooms" on public.classrooms for all to authenticated
using (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id))
with check (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id));

create policy "Enterprise admins manage classroom educators" on public.classroom_educators for all to authenticated
using (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id))
with check (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id));

create policy "Enterprise admins manage classroom enrollments" on public.classroom_student_enrollments for all to authenticated
using (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id))
with check (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id));

create policy "Enterprise admins manage instructional records" on public.educator_instructional_records for all to authenticated
using (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id))
with check (public.mac_is_platform_admin() or public.mac_is_organization_admin(organization_id));
