-- MAC Learn MVP Database Schema
-- Run this in Supabase SQL Editor.

create extension if not exists "uuid-ossp";

create type app_role as enum ('student', 'parent', 'tutor', 'admin');
create type approval_status as enum ('pending', 'approved', 'rejected');
create type session_status as enum ('pending', 'confirmed', 'completed', 'canceled', 'no_show');
create type payment_status as enum ('unpaid', 'paid', 'refunded', 'failed');
create type attendance_status as enum ('present', 'absent', 'late', 'excused');

create table public.profiles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade unique not null,
  full_name text not null,
  email text not null,
  phone text,
  role app_role not null default 'parent',
  created_at timestamptz default now()
);

create table public.students (
  id uuid primary key default uuid_generate_v4(),
  parent_id uuid references public.profiles(id) on delete cascade not null,
  first_name text not null,
  last_name text not null,
  grade_level text not null,
  school_name text,
  learning_goals text,
  notes text,
  created_at timestamptz default now()
);

create table public.subjects (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  grade_band text not null,
  description text,
  created_at timestamptz default now()
);

create table public.tutor_profiles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id) on delete cascade unique not null,
  bio text,
  approval_status approval_status default 'pending',
  hourly_rate numeric(10,2),
  subjects text[],
  grade_levels text[],
  created_at timestamptz default now()
);

create table public.tutor_availability (
  id uuid primary key default uuid_generate_v4(),
  tutor_id uuid references public.tutor_profiles(id) on delete cascade not null,
  day_of_week int not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null
);

create table public.sessions (
  id uuid primary key default uuid_generate_v4(),
  student_id uuid references public.students(id) on delete cascade not null,
  parent_id uuid references public.profiles(id) on delete cascade not null,
  tutor_id uuid references public.tutor_profiles(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  duration_minutes int not null default 60,
  status session_status default 'pending',
  zoom_link text,
  payment_status payment_status default 'unpaid',
  payment_id text,
  created_at timestamptz default now()
);

create table public.homework_uploads (
  id uuid primary key default uuid_generate_v4(),
  student_id uuid references public.students(id) on delete cascade not null,
  session_id uuid references public.sessions(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  uploaded_by uuid references public.profiles(id) on delete set null,
  file_url text not null,
  file_name text not null,
  notes text,
  created_at timestamptz default now()
);

create table public.session_notes (
  id uuid primary key default uuid_generate_v4(),
  session_id uuid references public.sessions(id) on delete cascade unique not null,
  tutor_id uuid references public.tutor_profiles(id) on delete cascade not null,
  attendance_status attendance_status default 'present',
  skills_covered text,
  performance_notes text,
  homework_assigned text,
  parent_summary text,
  internal_notes text,
  created_at timestamptz default now()
);

create table public.progress_reports (
  id uuid primary key default uuid_generate_v4(),
  student_id uuid references public.students(id) on delete cascade not null,
  tutor_id uuid references public.tutor_profiles(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  reporting_period text not null,
  strengths text,
  areas_for_improvement text,
  skills_mastered text,
  next_goals text,
  comments text,
  created_at timestamptz default now()
);

create table public.payments (
  id uuid primary key default uuid_generate_v4(),
  parent_id uuid references public.profiles(id) on delete cascade not null,
  student_id uuid references public.students(id) on delete set null,
  session_id uuid references public.sessions(id) on delete set null,
  amount numeric(10,2) not null,
  currency text default 'USD',
  provider text default 'paypal',
  provider_payment_id text,
  status payment_status default 'unpaid',
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.subjects enable row level security;
alter table public.tutor_profiles enable row level security;
alter table public.tutor_availability enable row level security;
alter table public.sessions enable row level security;
alter table public.homework_uploads enable row level security;
alter table public.session_notes enable row level security;
alter table public.progress_reports enable row level security;
alter table public.payments enable row level security;

create or replace function public.current_user_role()
returns app_role
language sql
security definer
set search_path = public
as $$
  select role from public.profiles where user_id = auth.uid()
$$;

create policy "Users can view their own profile"
on public.profiles for select
using (user_id = auth.uid() or public.current_user_role() = 'admin');

create policy "Users can update their own profile"
on public.profiles for update
using (user_id = auth.uid());

create policy "Authenticated users can view subjects"
on public.subjects for select
to authenticated
using (true);

create policy "Admins can manage subjects"
on public.subjects for all
using (public.current_user_role() = 'admin');

create policy "Admins manage students"
on public.students for all
using (public.current_user_role() = 'admin');

create policy "Admins manage tutors"
on public.tutor_profiles for all
using (public.current_user_role() = 'admin');

create policy "Admins manage sessions"
on public.sessions for all
using (public.current_user_role() = 'admin');

create policy "Admins manage payments"
on public.payments for all
using (public.current_user_role() = 'admin');

create policy "Parents view own students"
on public.students for select
using (parent_id in (select id from public.profiles where user_id = auth.uid()));

create policy "Parents create own students"
on public.students for insert
with check (parent_id in (select id from public.profiles where user_id = auth.uid()));

insert into public.subjects (name, grade_band, description) values
('Reading / ELA', 'K-12', 'Reading comprehension, vocabulary, literacy, and English language arts'),
('Writing', 'K-12', 'Grammar, composition, essays, and written communication'),
('Math', 'K-12', 'Foundational math, algebra, geometry, statistics, and calculus readiness'),
('Science', 'K-12', 'General science, biology, chemistry, physics, and earth science'),
('Social Studies', 'K-12', 'History, civics, geography, economics, and culture'),
('Foreign Language', 'K-12', 'Spanish, French, Haitian Creole, and other language support'),
('Computer Science / Technology', 'K-12', 'Digital literacy, coding, robotics, and technology skills'),
('Test Prep', '3-12', 'FAST, EOC, SAT, ACT, and other assessment preparation'),
('Study Skills', 'K-12', 'Organization, time management, note-taking, and learning strategies');

