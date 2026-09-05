-- MAC Learn: evaluate Educator classroom-assignment lifecycle in the
-- classroom tenant calendar instead of the database session date.

create or replace function public.mac_classroom_calendar_date(
  p_classroom_id uuid
)
returns date
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select (
    now() at time zone coalesce(
      (
        select site.timezone
        from public.classrooms classroom
        join public.sites site
          on site.id = classroom.site_id
         and site.organization_id = classroom.organization_id
        where classroom.id = p_classroom_id
      ),
      (
        select configuration.default_timezone
        from public.classrooms classroom
        join public.organization_configurations configuration
          on configuration.organization_id = classroom.organization_id
        where classroom.id = p_classroom_id
      ),
      'UTC'
    )
  )::date;
$$;

revoke all on function public.mac_classroom_calendar_date(uuid) from public, anon;
grant execute on function public.mac_classroom_calendar_date(uuid) to authenticated;

create or replace function public.mac_is_active_classroom_educator(
  requested_classroom_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
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
      and assignment.assigned_from <= public.mac_classroom_calendar_date(classroom.id)
      and (
        assignment.assigned_until is null
        or assignment.assigned_until >= public.mac_classroom_calendar_date(classroom.id)
      )
      and enterprise_user.account_status = 'active'
      and role_assignment.status = 'active'
      and role_assignment.valid_from <= now()
      and (role_assignment.valid_until is null or role_assignment.valid_until > now())
      and role_assignment.role_key in ('teacher', 'academic_lead')
      and role_assignment.organization_id = classroom.organization_id
      and (role_assignment.site_id is null or role_assignment.site_id = classroom.site_id)
  );
$$;

revoke all on function public.mac_is_active_classroom_educator(uuid) from public, anon;
grant execute on function public.mac_is_active_classroom_educator(uuid) to authenticated;

comment on function public.mac_classroom_calendar_date(uuid) is
  'Returns the classroom-local calendar date using site timezone, then organization default timezone, then UTC.';
comment on function public.mac_is_active_classroom_educator(uuid) is
  'Returns true only when the authenticated Educator has a currently active classroom assignment evaluated in the classroom tenant calendar and a matching active enterprise role scope.';
