import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("Teacher and Academic Lead assignments route to the secure Educator workspace", async () => {
  const [resolver, page] = await Promise.all([read("src/lib/auth/workspace.ts"), read("src/app/educator/page.tsx")]);
  assert.match(resolver, /case "teacher":[\s\S]*case "academic_lead":[\s\S]*return "\/educator"/);
  assert.match(page, /role\.role === "teacher" \|\| role\.role === "academic_lead"/);
  assert.match(page, /await requireRole\(assignment\.role/);
  assert.doesNotMatch(page, /createAdminClient|service_role/);
});

test("Educator workspace is relationship-scoped through classroom RLS", async () => {
  const [page, migration] = await Promise.all([
    read("src/app/educator/page.tsx"),
    read("supabase/migrations/20260828103000_enforce_educator_data_access.sql"),
  ]);
  for (const table of ["classrooms", "classroom_educators", "classroom_student_enrollments", "students", "educator_instructional_records"]) {
    assert.match(page, new RegExp(`from\\(\\"${table}\\"\\)`));
  }
  assert.match(migration, /assignment\.user_id = auth\.uid\(\)/);
  assert.match(migration, /role_assignment\.organization_id = classroom\.organization_id/);
  assert.match(migration, /role_assignment\.site_id is null or role_assignment\.site_id = classroom\.site_id/);
  assert.match(migration, /public\.mac_educator_can_access_student\(classroom_id, student_id\)/);
});

test("Educator workspace exposes classroom, student, and instructional record sections", async () => {
  const page = await read("src/app/educator/page.tsx");
  for (const label of ["Classrooms", "Assigned students", "Instructional records"]) assert.match(page, new RegExp(label));
  assert.match(page, /organizationResult/);
  assert.match(page, /siteResult/);
  assert.match(page, /const scopeLabel =/);
  assert.match(page, /classroom\.status \?\? "unspecified"/);
});
