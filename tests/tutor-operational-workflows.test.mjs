import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("Platform Admin scheduling is self-authorizing and tenant scoped", async () => {
  const migration = await read("supabase/migrations/20260830004003_enable_tutor_operational_workflows.sql");
  assert.match(migration, /mac_is_platform_admin\(\)/);
  assert.match(migration, /student and Tutor must belong to the same organization/);
  assert.match(migration, /student is outside the Tutor site scope/);
  assert.match(migration, /revoke all on function public\.mac_platform_admin_schedule_session/);
});

test("Tutor writes receive only the required authenticated grants", async () => {
  const migration = await read("supabase/migrations/20260830004003_enable_tutor_operational_workflows.sql");
  assert.match(migration, /grant insert on table[\s\S]*public\.tutor_availability/);
  assert.match(migration, /grant insert on table[\s\S]*public\.session_notes/);
  assert.match(migration, /grant insert on table[\s\S]*public\.progress_reports/);
  assert.doesNotMatch(migration, /grant (all|insert).*public\.sessions/i);
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
  assert.match(adminActions, /mac_platform_admin_schedule_session/);
  assert.match(tutorForms, /A scheduled session is required/);
  assert.match(tutorForms, /An assigned student is required/);
  assert.match(tutorActions, /mac_current_tutor_id/);
  assert.match(tutorActions, /revalidatePath\("\/tutor"\)/);
});
