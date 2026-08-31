import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("guardian assignments route to the Family workspace", async () => {
  const [resolver, page] = await Promise.all([
    read("src/lib/auth/workspace.ts"),
    read("src/app/family/page.tsx"),
  ]);
  assert.match(resolver, /case "guardian":[\s\S]*return "\/family"/);
  assert.match(page, /await requireRole\("guardian"/);
  assert.match(page, /context\.roles\.find\(\(role\) => role\.role === "guardian"\)/);
});

test("Family workspace reads only RLS-protected and parent-facing data", async () => {
  const page = await read("src/app/family/page.tsx");
  for (const table of ["sessions", "progress_reports"]) {
    assert.match(page, new RegExp(`\\.from\\("${table}"\\)`));
  }
  assert.match(page, /\.rpc\("mac_family_students"\)/);
  assert.match(page, /\.rpc\("mac_family_session_summaries"\)/);
  assert.match(page, /\.in\("student_id", studentIds\)/);
  assert.doesNotMatch(page, /\.from\("students"\)/);
  assert.match(page, /\.in\("status", \["pending", "confirmed"\]\)/);
  assert.doesNotMatch(page, /\.from\("session_notes"\)/);
  assert.doesNotMatch(page, /performance_notes|internal_notes|createAdminClient|service_role/);
});

test("Family workspace exposes the requested sections", async () => {
  const page = await read("src/app/family/page.tsx");
  for (const label of ["Linked students", "Scheduled sessions", "Attendance and session summaries", "Progress and upcoming goals"]) {
    assert.match(page, new RegExp(label));
  }
});

test("Family migration preserves canonical tenant and role boundaries", async () => {
  const migration = await read("supabase/migrations/20260830235418_add_family_workspace_access.sql");
  assert.match(migration, /mac_family_can_access_student/);
  assert.match(migration, /mac_family_students/);
  assert.match(migration, /guardian_student_relationships/);
  assert.match(migration, /relationship\.educational_access/);
  assert.match(migration, /enterprise_user\.account_status = 'active'/);
  assert.match(migration, /mac_has_role\('guardian'/);
  assert.match(migration, /create policy "Authenticated families view only related students"[\s\S]*mac_family_can_access_student\(id\)/);
  assert.match(migration, /drop policy if exists "Admins manage sessions"/);
  assert.match(migration, /mac_can_use_legacy_admin_access\(\)/);
  assert.match(migration, /revoke all on function public\.mac_family_session_summaries\(\)[\s\S]*from public, anon/);
  assert.match(migration, /grant execute on function public\.mac_family_session_summaries\(\)[\s\S]*to authenticated/);
});

test("Family workspace formats records in each student's tenant timezone", async () => {
  const page = await read("src/app/family/page.tsx");
  assert.match(page, /organizationTimeZones/);
  assert.match(page, /siteTimeZones/);
  assert.match(page, /timeZoneForStudent/);
  assert.match(page, /studentTimeZones\.get\(summary\.student_id\)/);
});

test("successful note creation suppresses the empty-session warning", async () => {
  const form = await read("src/app/tutor/TutorOperationForms.tsx");
  assert.match(form, /sessions\.length === 0 && !note\.success/);
});
