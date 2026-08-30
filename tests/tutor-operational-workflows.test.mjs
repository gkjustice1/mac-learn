import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("Platform Admin scheduling is self-authorizing and tenant scoped", async () => {
  const migration = await read("supabase/migrations/20260830004003_enable_tutor_operational_workflows.sql");
  assert.match(migration, /mac_is_platform_admin\(\)/);
  assert.match(migration, /student and Tutor must belong to the same organization/);
  assert.match(migration, /student is outside the Tutor site scope/);
  assert.match(migration, /assignment\.site_id = v_student_site_id/);
  assert.match(migration, /revoke all on function public\.mac_platform_admin_schedule_session/);
  assert.match(migration, /tutor_availability_valid_window[\s\S]*not valid/);
});

test("canonical student sessions do not require a legacy parent profile", async () => {
  const migration = await read("supabase/migrations/20260830224500_allow_canonical_sessions_without_legacy_parent.sql");
  const databaseTest = await read("supabase/tests/tutor_operational_workflows.test.sql");
  assert.match(migration, /alter column parent_id drop not null/);
  assert.match(migration, /foreign key \(parent_id\) references public\.profiles\(id\) on delete set null\s+not valid/);
  assert.match(migration, /validate constraint sessions_parent_id_fkey/);
  assert.match(databaseTest, /Platform Admin can schedule a canonically enrolled student without a legacy parent profile/);
  assert.match(databaseTest, /Tutor RLS exposes the assigned canonical student session/);
});

test("Tutor writes receive only the required authenticated grants", async () => {
  const migration = await read("supabase/migrations/20260830004003_enable_tutor_operational_workflows.sql");
  assert.match(migration, /grant insert on table[\s\S]*public\.tutor_availability/);
  assert.match(migration, /grant insert on table[\s\S]*public\.session_notes/);
  assert.match(migration, /grant insert on table[\s\S]*public\.progress_reports/);
  assert.doesNotMatch(migration, /grant (all|insert).*public\.sessions/i);
  assert.match(migration, /session\.end_time <= now\(\)/);
  assert.match(migration, /drop policy if exists "Tutors write their session notes"/);
});

test("administrator and Tutor operational forms are connected to Server Actions", async () => {
  const [adminForm, tutorForms, adminActions, tutorActions] = await Promise.all([
    read("src/app/platform/tutor-operations/SessionAssignmentForm.tsx"),
    read("src/app/tutor/TutorOperationForms.tsx"),
    read("src/app/platform/tutor-operations/actions.ts"),
    read("src/app/tutor/actions.ts"),
  ]);
  assert.match(adminForm, /aria-label="Student selection"/);
  assert.match(adminForm, /aria-label="Tutor selection"/);
  assert.match(adminForm, /new Date\(localValue\)\.toISOString\(\)/);
  assert.match(adminForm, /const \[state, action, pending\] = useActionState/);
  assert.match(adminForm, /<Submit disabled=\{unavailable\} pending=\{pending\}/);
  assert.match(adminForm, /tutor\.scopes\.some/);
  assert.match(adminActions, /time-zone offset/);
  assert.match(adminActions, /mac_platform_admin_schedule_session/);
  assert.match(tutorForms, /A scheduled session is required/);
  assert.match(tutorForms, /An assigned student is required/);
  assert.match(tutorForms, /availabilityPending/);
  assert.match(tutorForms, /!sessions\.length \|\| notePending/);
  assert.match(tutorForms, /!students\.length \|\| reportPending/);
  assert.match(tutorActions, /mac_current_tutor_id/);
  assert.match(tutorActions, /revalidatePath\("\/tutor"\)/);
});

test("Tutor note choices exclude sessions that already have a note", async () => {
  const [page, actions] = await Promise.all([
    read("src/app/tutor/page.tsx"),
    read("src/app/tutor/actions.ts"),
  ]);
  assert.match(page, /notedSessionIds/);
  assert.match(page, /sessionsWithoutNotes/);
  assert.match(page, /\.lte\("end_time", "now"\)/);
  assert.match(page, /elapsedSessionIds\.has\(session\.id\)/);
  assert.match(page, /sessions=\{sessionsWithoutNotes\.map/);
  assert.match(actions, /Session notes can only be created after the session ends/);
  assert.match(actions, /\.eq\("tutor_id", tutorId\)/);
});
