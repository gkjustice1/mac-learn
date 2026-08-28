-- MAC Learn: student-owned learning data access
-- An active student may read only the enterprise student record linked to
-- their authenticated person identity and that student's active learning data.

create or replace function public.mac_current_student_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select student.id
  from public.students student
  join public.users enterprise_user on enterprise_user.person_id = student.person_id
  where enterprise_user.id = auth.uid()
    and enterprise_user.account_status = 'active'
    and student.enterprise_status = 'active'
    and (
      public.mac_has_role('student', student.organization_id, student.primary_site_id)
      or (
        student.primary_site_id is not null
        and public.mac_has_role('student', student.organization_id, null)
      )
    )
$$;

revoke all on function public.mac_current_student_ids() from public;
grant execute on function public.mac_current_student_ids() to authenticated;

create policy "Students view their own enterprise record"
on public.students for select to authenticated
using (id in (select public.mac_current_student_ids()));

create policy "Students view active own classroom enrollments"
on public.classroom_student_enrollments for select to authenticated
using (
  student_id in (select public.mac_current_student_ids())
  and status = 'active'
  and enrolled_from <= current_date
  and (enrolled_until is null or enrolled_until >= current_date)
);

create policy "Students view their enrolled classrooms"
on public.classrooms for select to authenticated
using (status = 'active' and exists (
  select 1
  from public.classroom_student_enrollments enrollment
  where enrollment.classroom_id = classrooms.id
    and enrollment.organization_id = classrooms.organization_id
    and enrollment.student_id in (select public.mac_current_student_ids())
    and enrollment.status = 'active'
    and enrollment.enrolled_from <= current_date
    and (enrollment.enrolled_until is null or enrollment.enrolled_until >= current_date)
));

create policy "Students view their own instructional records"
on public.educator_instructional_records for select to authenticated
using (
  student_id in (select public.mac_current_student_ids())
  and exists (
    select 1
    from public.classroom_student_enrollments enrollment
    join public.classrooms classroom
      on classroom.id = enrollment.classroom_id
      and classroom.organization_id = enrollment.organization_id
    where enrollment.student_id = educator_instructional_records.student_id
      and enrollment.classroom_id = educator_instructional_records.classroom_id
      and enrollment.organization_id = educator_instructional_records.organization_id
      and enrollment.status = 'active'
      and enrollment.enrolled_from <= current_date
      and (enrollment.enrolled_until is null or enrollment.enrolled_until >= current_date)
      and classroom.status = 'active'
  )
);

comment on policy "Students view their own enterprise record" on public.students is
  'An active student identity can view only the student record linked by public.users.person_id.';
comment on policy "Students view active own classroom enrollments" on public.classroom_student_enrollments is
  'Students can view only their current classroom enrollments.';
comment on policy "Students view their own instructional records" on public.educator_instructional_records is
  'Students have read-only access to instructional records for their own student record.';
