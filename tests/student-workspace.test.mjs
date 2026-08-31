import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("Student assignments route to the secure Student workspace", async () => {
  const [resolver, page] = await Promise.all([read("src/lib/auth/workspace.ts"), read("src/app/student/page.tsx")]);
  assert.match(resolver, /case "student":[\s\S]*return "\/student"/);
  assert.match(page, /await requireRole\("student"/);
  assert.doesNotMatch(page, /createAdminClient|service_role/);
});

test("Student workspace exposes each requested learning section", async () => {
  const page = await read("src/app/student/page.tsx");
  for (const label of ["Sessions", "Assignments", "Learning content", "Tutor feedback", "Progress"]) assert.match(page, new RegExp(label));
  assert.match(page, /\.rpc\("mac_current_student_ids"\)/);
  assert.match(page, /\.rpc\("mac_student_feedback"\)/);
});

test("Student migration preserves canonical identity and excludes private notes", async () => {
  const migration = await read("supabase/migrations/20260831153000_add_student_workspace_access.sql");
  assert.match(migration, /student\.person_id = enterprise_user\.person_id/);
  assert.match(migration, /assignment\.organization_id = student\.organization_id/);
  assert.match(migration, /assignment\.site_id is null or assignment\.site_id = student\.primary_site_id/);
  assert.match(migration, /session\.student_id in \(select public\.mac_current_student_ids\(\)\)/);
  assert.match(migration, /revoke all on function public\.mac_student_feedback\(\) from public, anon/);
  assert.doesNotMatch(migration, /internal_notes|parent_summary/);
});
