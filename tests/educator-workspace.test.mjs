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

test("Educator classroom reads are explicitly anchored to the signed-in user and active classrooms", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /from\("classroom_educators"\)[\s\S]*\.eq\("user_id", context\.user\.id\)/);
  assert.match(page, /\.eq\("status", "active"\)[\s\S]*\.lte\("assigned_from", today\)/);
  assert.match(page, /from\("classrooms"\)[\s\S]*\.eq\("status", "active"\)/);
});

test("Large student and instructional-record scopes are paged at the database boundary", async () => {
  const [page, migration] = await Promise.all([read("src/app/educator/page.tsx"), read("supabase/migrations/20260902165000_add_educator_workspace_page_rpcs.sql")]);
  assert.match(page, /rpc\("mac_get_educator_student_page"/);
  assert.match(page, /rpc\("mac_get_educator_instructional_record_page"/);
  assert.doesNotMatch(page, /classroom_student_enrollments/);
  assert.doesNotMatch(page, /educator_instructional_records[\s\S]*\.in\("classroom_id"/);
  assert.match(migration, /create or replace function public\.mac_get_educator_student_page/);
  assert.match(migration, /create or replace function public\.mac_get_educator_instructional_record_page/);
  assert.match(migration, /mac_is_active_classroom_educator\(classroom\.id\)/);
  assert.match(migration, /count\(\*\) over \(\) as total_count/);
  assert.match(migration, /limit least\(greatest\(p_limit, 1\), 100\)/);
});

test("Student page RPC returns memberships only for visible students", async () => {
  const migration = await read("supabase/migrations/20260902165000_add_educator_workspace_page_rpcs.sql");
  assert.match(migration, /where enrollment\.student_id = counted\.id/);
  assert.match(migration, /'classroom_name', classroom\.name/);
  assert.match(migration, /enrollment\.status = 'active'/);
});

test("Educator scope-name policies follow active Teacher or Academic Lead role scope", async () => {
  const migration = await read("supabase/migrations/20260901104500_add_educator_scope_name_access.sql");
  assert.match(migration, /assignment\.user_id = auth\.uid\(\)/);
  assert.match(migration, /assignment\.role_key in \('teacher', 'academic_lead'\)/);
  assert.match(migration, /assignment\.organization_id = requested_organization_id/);
  assert.match(migration, /assignment\.site_id is null[\s\S]*assignment\.site_id = requested_site_id/);
});

test("Independent paginator links preserve the other page parameters", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /function pageHref\(params: SearchParams/);
  assert.match(page, /\["classroomPage", "studentPage", "recordPage"\]/);
  assert.match(page, /key === parameter \? String\(value\) : params\[key\]/);
  assert.match(page, /params=\{params\}/);
});

test("Visible cards retain row-specific scope labels and nullable classroom status fallback", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /scopeLabel\(c\.organization_id, c\.site_id\)/);
  assert.match(page, /scopeLabel\(s\.organization_id, s\.primary_site_id\)/);
  assert.match(page, /scopeLabel\(r\.organization_id, r\.site_id\)/);
  assert.match(page, /c\.status \?\? "unspecified"/);
});
