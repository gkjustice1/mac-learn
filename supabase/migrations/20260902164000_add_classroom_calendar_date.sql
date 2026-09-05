-- MAC Learn: define the classroom tenant calendar before Educator paging RPCs
-- depend on it.

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

comment on function public.mac_classroom_calendar_date(uuid) is
  'Returns the classroom-local calendar date using site timezone, then organization default timezone, then UTC.';
