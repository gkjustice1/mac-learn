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

test("Educator workspace remains relationship-scoped through classroom RLS", async () => {
  const [page, migration] = await Promise.all([read("src/app/educator/page.tsx"), read("supabase/migrations/20260828103000_enforce_educator_data_access.sql")]);
  for (const table of ["classrooms", "classroom_educators", "classroom_student_enrollments", "students", "educator_instructional_records"]) assert.match(page, new RegExp(`from\\(\\"${table}\\"\\)`));
  assert.match(migration, /assignment\.user_id = auth\.uid\(\)/);
  assert.match(migration, /role_assignment\.organization_id = classroom\.organization_id/);
  assert.match(migration, /role_assignment\.site_id is null or role_assignment\.site_id = classroom\.site_id/);
  assert.match(migration, /public\.mac_educator_can_access_student\(classroom_id, student_id\)/);
});

test("Educator cards use row-specific scope labels and active assignment metrics", async () => {
  const page = await read("src/app/educator/page.tsx");
  for (const label of ["Classrooms", "Assigned students", "Instructional records"]) assert.match(page, new RegExp(label));
  assert.match(page, /scopeLabel\(classroom\.organization_id, classroom\.site_id\)/);
  assert.match(page, /scopeLabel\(student\.organization_id, student\.primary_site_id\)/);
  assert.match(page, /scopeLabel\(record\.organization_id, classroom\?\.site_id\)/);
  assert.match(page, /\.eq\("status", "active"\)\.lte\("assigned_from", today\)/);
  assert.match(page, /assigned_until\.is\.null,assigned_until\.gte/);
  assert.match(page, /classroom\.status \?\? "unspecified"/);
});

test("Educator scope-name policies follow active Teacher or Academic Lead role scope before classroom assignment", async () => {
  const migration = await read("supabase/migrations/20260901104500_add_educator_scope_name_access.sql");
  assert.match(migration, /create or replace function public\.mac_is_active_educator_scope/);
  assert.match(migration, /assignment\.user_id = auth\.uid\(\)/);
  assert.match(migration, /assignment\.role_key in \('teacher', 'academic_lead'\)/);
  assert.match(migration, /assignment\.organization_id = requested_organization_id/);
  assert.match(migration, /assignment\.site_id is null[\s\S]*assignment\.site_id = requested_site_id/);
  assert.match(migration, /create policy "Educators view assigned organizations"/);
  assert.match(migration, /mac_is_active_educator_scope\(id, null\)/);
  assert.match(migration, /create policy "Educators view assigned sites"/);
  assert.match(migration, /mac_is_active_educator_scope\(organization_id, id\)/);
  assert.doesNotMatch(migration, /for all|for insert|for update|for delete/i);
});

test("Educator students, records, and enrollment memberships cannot silently stop at Supabase max_rows", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /const PAGE_SIZE = 100/);
  assert.match(page, /students[\s\S]*\{ count: "exact" \}[\s\S]*\.range\(studentFrom, studentFrom \+ PAGE_SIZE - 1\)/);
  assert.match(page, /educator_instructional_records[\s\S]*\{ count: "exact" \}[\s\S]*\.range\(recordFrom, recordFrom \+ PAGE_SIZE - 1\)/);
  assert.match(page, /while \(true\)[\s\S]*classroom_student_enrollments[\s\S]*\.range\(from, from \+ PAGE_SIZE - 1\)/);
  assert.match(page, /PageLinks page=\{studentPage\}/);
  assert.match(page, /PageLinks page=\{recordPage\}/);
});
