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

test("Classrooms, students, and instructional records are paged at the database boundary", async () => {
  const [page, migration] = await Promise.all([read("src/app/educator/page.tsx"), read("supabase/migrations/20260902165000_add_educator_workspace_page_rpcs.sql")]);
  assert.match(page, /rpc\("mac_get_educator_classroom_page"/);
  assert.match(page, /rpc\("mac_get_educator_student_page"/);
  assert.match(page, /rpc\("mac_get_educator_instructional_record_page"/);
  assert.doesNotMatch(page, /from\("classroom_educators"\)/);
  assert.doesNotMatch(page, /classroom_student_enrollments/);
  assert.doesNotMatch(page, /educator_instructional_records[\s\S]*\.in\("classroom_id"/);
  assert.match(migration, /create or replace function public\.mac_get_educator_classroom_page/);
  assert.match(migration, /assignment\.user_id = auth\.uid\(\)/);
  assert.match(migration, /classroom\.status = 'active'/);
  assert.match(migration, /mac_is_active_classroom_educator\(classroom\.id\)/);
});

test("Educator page RPCs preserve exact totals even when the requested page has no rows", async () => {
  const migration = await read("supabase/migrations/20260902165000_add_educator_workspace_page_rpcs.sql");
  assert.match(migration, /totals as \([\s\S]*count\(\*\)::bigint as total_count/);
  assert.match(migration, /'total_count', totals\.total_count/);
  assert.doesNotMatch(migration, /coalesce\(max\(total_count\), 0\)/);
  assert.match(migration, /limit least\(greatest\(p_limit, 1\), 100\)/);
});

test("Student page RPC returns memberships only for visible students", async () => {
  const migration = await read("supabase/migrations/20260902165000_add_educator_workspace_page_rpcs.sql");
  assert.match(migration, /where enrollment\.student_id = paged\.id/);
  assert.match(migration, /'classroom_name', classroom\.name/);
  assert.match(migration, /enrollment\.status = 'active'/);
});

test("Educator student and record pages require the canonical Student lifecycle", async () => {
  const migration = await read("supabase/migrations/20260902165000_add_educator_workspace_page_rpcs.sql");
  const studentFunction = migration.slice(
    migration.indexOf("create or replace function public.mac_get_educator_student_page"),
    migration.indexOf("create or replace function public.mac_get_educator_instructional_record_page"),
  );
  const recordFunction = migration.slice(migration.indexOf("create or replace function public.mac_get_educator_instructional_record_page"));
  for (const functionBody of [studentFunction, recordFunction]) {
    assert.match(functionBody, /student\.enterprise_status = 'active'/);
    assert.match(functionBody, /student\.enrollment_start_date <= public\.mac_relationship_calendar_date/);
    assert.match(functionBody, /student\.enrollment_end_date >= public\.mac_relationship_calendar_date/);
  }
});

test("Instructional record page requires a current classroom enrollment", async () => {
  const migration = await read("supabase/migrations/20260902165000_add_educator_workspace_page_rpcs.sql");
  const recordFunction = migration.slice(migration.indexOf("create or replace function public.mac_get_educator_instructional_record_page"));
  assert.match(recordFunction, /exists \([\s\S]*from public\.classroom_student_enrollments enrollment/);
  assert.match(recordFunction, /enrollment\.classroom_id = record\.classroom_id/);
  assert.match(recordFunction, /enrollment\.student_id = record\.student_id/);
  assert.match(recordFunction, /enrollment\.status = 'active'/);
  assert.match(recordFunction, /mac_relationship_calendar_date/);
});

test("Educator student-access RLS uses the same tenant calendar as workspace paging", async () => {
  const migration = await read("supabase/migrations/20260903125500_align_educator_rls_tenant_calendar.sql");
  assert.match(migration, /create or replace function public\.mac_educator_can_access_student/);
  assert.match(migration, /mac_is_active_classroom_educator\(requested_classroom_id\)/);
  assert.match(migration, /enrollment\.classroom_id = requested_classroom_id/);
  assert.match(migration, /enrollment\.student_id = requested_student_id/);
  assert.match(migration, /enrollment\.status = 'active'/);
  assert.match(migration, /enrollment\.enrolled_from <= public\.mac_relationship_calendar_date/);
  assert.match(migration, /enrollment\.enrolled_until >= public\.mac_relationship_calendar_date/);
  assert.doesNotMatch(migration, /enrollment\.enrolled_from <= current_date/);
});

test("Page numbers are clamped before PostgreSQL integer RPC offsets are constructed", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /const MAX_PAGE = Math\.floor\(2147483647 \/ PAGE_SIZE\) \+ 1/);
  assert.match(page, /Math\.min\(parsed, MAX_PAGE\)/);
  assert.match(page, /p_offset: \(studentPage - 1\) \* PAGE_SIZE/);
  assert.match(page, /p_offset: \(recordPage - 1\) \* PAGE_SIZE/);
});

test("Stale section pages redirect to the last available result page", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /function availablePages\(count: number\)/);
  assert.match(page, /classroomPage: Math\.min\(classroomPage, availablePages\(classroomCount\)\)/);
  assert.match(page, /studentPage: Math\.min\(studentPage, availablePages\(studentCount\)\)/);
  assert.match(page, /recordPage: Math\.min\(recordPage, availablePages\(recordCount\)\)/);
  assert.match(page, /redirect\(normalizedPageHref\(params, normalizedPages\)\)/);
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
  assert.match(page, /function pageHref\(\s*params: SearchParams/);
  assert.match(page, /\["classroomPage", "studentPage", "recordPage"\]/);
  assert.match(page, /key === parameter \? String\(value\) : params\[key\]/);
  assert.match(page, /params=\{params\}/);
});

test("Visible cards retain row-specific scope labels and nullable classroom status fallback", async () => {
  const page = await read("src/app/educator/page.tsx");
  assert.match(page, /scopeLabel\(classroom\.organization_id, classroom\.site_id\)/);
  assert.match(page, /scopeLabel\(student\.organization_id, student\.primary_site_id\)/);
  assert.match(page, /scopeLabel\(record\.organization_id, record\.site_id\)/);
  assert.match(page, /classroom\.status \?\? "unspecified"/);
});
