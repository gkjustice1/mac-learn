import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const workspace = await readFile("src/app/tutor/page.tsx", "utf8");
const resolver = await readFile("src/lib/auth/workspace.ts", "utf8");
const profileMigration = await readFile(
  "supabase/migrations/20260829221604_link_tutor_profiles_to_assignments.sql",
  "utf8"
);

test("Tutor assignments route to the Tutor workspace", () => {
  assert.match(resolver, /case "tutor":[\s\S]*return "\/tutor"/);
});

test("Tutor workspace enforces the exact active Tutor scope", () => {
  assert.match(workspace, /context\.roles\.find\(\(role\) => role\.role === "tutor"\)/);
  assert.match(workspace, /await requireRole\("tutor"/);
  assert.match(workspace, /organizationId: assignment\.organizationId/);
  assert.match(workspace, /siteId: assignment\.siteId/);
});

test("Tutor workspace loads only RLS-protected operational records", () => {
  assert.match(workspace, /mac_current_tutor_id/);
  for (const table of [
    "students",
    "sessions",
    "tutor_availability",
    "session_notes",
    "progress_reports",
  ]) {
    assert.match(workspace, new RegExp(`\\.from\\("${table}"\\)`));
  }
  assert.doesNotMatch(workspace, /createAdminClient|service_role/);
});

test("Tutor workspace exposes all requested operational sections", () => {
  for (const section of [
    "Assigned students",
    "Sessions",
    "Availability",
    "Session notes",
    "Progress reports",
  ]) {
    assert.match(workspace, new RegExp(section));
  }
});

test("Tutor profile backfill handles users with multiple active scopes", () => {
  assert.match(profileMigration, /select distinct on \(profile\.id\)/);
  assert.match(profileMigration, /order by[\s\S]*profile\.id/);
});

test("Tutor scope grants organization and site name visibility", () => {
  assert.match(profileMigration, /"Tutors view assigned organizations"/);
  assert.match(profileMigration, /mac_tutor_can_view_organization\(id\)/);
  assert.match(profileMigration, /"Tutors view assigned sites"/);
  assert.match(profileMigration, /mac_has_role\('tutor', organization_id, id\)/);
});
