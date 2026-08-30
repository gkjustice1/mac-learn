-- MAC Learn: allow Tutor sessions for canonically enrolled students.
--
-- Canonical family access is represented by guardian_student_relationships.
-- sessions.parent_id remains as a nullable compatibility reference for legacy
-- records and must not block scheduling a canonically enrolled student.

alter table public.sessions
  alter column parent_id drop not null;

alter table public.sessions
  drop constraint if exists sessions_parent_id_fkey;

alter table public.sessions
  add constraint sessions_parent_id_fkey
  foreign key (parent_id) references public.profiles(id) on delete set null;
