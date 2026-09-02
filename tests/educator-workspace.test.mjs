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

test("Educator workspace explicitly scopes all instructional reads from active classroom relationships", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /classroomAssignments[\s\S]*from\("classroom_educators"\)[\s\S]*\.eq\("user_id", context\.user\.id\)/);
  assert.match(page, /const candidateClassroomIds = \[\.\.\.new Set\(classroomAssignments\.map/);
  assert.match(page, /from\("classrooms"\)[\s\S]*\.in\("id", ids\)[\s\S]*\.eq\("status", "active"\)/);
  assert.match(page, /const classroomIds = activeClassrooms\.map/);
  assert.match(page, /classroom_student_enrollments[\s\S]*\.in\("classroom_id", classroomChunk\)/);
  assert.match(page, /const accessibleStudentIds = \[\.\.\.new Set\(enrollments\.map/);
  assert.match(page, /from\("students"\)[\s\S]*\.in\("id", studentPageIds\)/);
  assert.match(page, /educator_instructional_records[\s\S]*\.in\("classroom_id", classroomIds\)/);
  assert.doesNotMatch(page, /from\("students"\)\.select\([^\n]+\{ count: "exact" \}/);
});

test("Educator cards use row-specific scope labels and active assignment metrics", async () => {
  const page = await read("src/app/educator/page.tsx");
  for (const label of ["Classrooms", "Assigned students", "Instructional records"]) assert.match(page, new RegExp(label));
  assert.match(page, /scopeLabel\(classroom\.organization_id, classroom\.site_id\)/);
  assert.match(page, /scopeLabel\(student\.organization_id, student\.primary_site_id\)/);
  assert.match(page, /scopeLabel\(record\.organization_id, classroom\?\.site_id\)/);
  assert.match(page, /\.eq\("status", "active"\)[\s\S]*\.lte\("assigned_from", today\)/);
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
});

test("Every offset-paginated Educator relationship has deterministic ordering", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /classroom_educators[\s\S]*\.order\("classroom_id"\)[\s\S]*\.order\("id"\)[\s\S]*\.range\(assignmentFrom/);
  assert.match(page, /classroom_student_enrollments[\s\S]*\.order\("student_id"\)[\s\S]*\.order\("classroom_id"\)[\s\S]*\.order\("id"\)[\s\S]*\.range\(enrollmentFrom/);
  assert.match(page, /from\("students"\)[\s\S]*\.order\("last_name"\)[\s\S]*\.order\("first_name"\)[\s\S]*\.order\("id"\)/);
  assert.match(page, /educator_instructional_records[\s\S]*\.order\("occurred_on", \{ ascending: false \}\)[\s\S]*\.order\("id", \{ ascending: false \}\)[\s\S]*\.range\(recordFrom/);
});

test("Classrooms, students, and records expose complete counts with bounded visible pages", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /const PAGE_SIZE = 100/);
  assert.match(page, /const classroomCount = classroomIds\.length/);
  assert.match(page, /const studentCount = accessibleStudentIds\.length/);
  assert.match(page, /educator_instructional_records[\s\S]*\{ count: "exact" \}/);
  assert.match(page, /PageLinks page=\{classroomPage\}/);
  assert.match(page, /PageLinks page=\{studentPage\}/);
  assert.match(page, /PageLinks page=\{recordPage\}/);
});

test("Instructional record names are loaded from the record page rather than the visible Student page", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /const recordStudentIds = \[\.\.\.new Set\(records\.map/);
  assert.match(page, /recordStudentIds\.length[\s\S]*from\("students"\)\.select\("id, first_name, last_name"\)\.in\("id", recordStudentIds\)/);
  assert.match(page, /studentNames = new Map\(\(recordStudentsResult\.data/);
});
