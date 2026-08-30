-- Expose the Tutor workspace read model to authenticated users.
-- Row-level security remains authoritative for every granted table.

grant select on table
  public.students,
  public.sessions,
  public.subjects,
  public.tutor_availability,
  public.session_notes,
  public.progress_reports
to authenticated;

-- Tutor workspace data is never available to unauthenticated callers.
revoke select on table
  public.students,
  public.sessions,
  public.subjects,
  public.tutor_availability,
  public.session_notes,
  public.progress_reports
from anon;
