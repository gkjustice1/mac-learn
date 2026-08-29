import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const source = await readFile(new URL("../src/app/actions.ts", import.meta.url), "utf8");

test("invitation provisioning is server-only and organization-scoped", () => {
  assert.match(source, /"use server"/);
  assert.match(source, /await requireOrganizationAdmin\(organizationId\)/);
  assert.match(source, /\.eq\("status", "active"\)/);
  assert.match(source, /inviteUserByEmail/);
  assert.match(source, /redirectTo: `\$\{appUrl\}\/auth\/callback`/);
  assert.match(source, /account_status: "invited"/);
});

test("invitation provisioning excludes administrative role escalation", () => {
  assert.match(source, /const PROVISIONABLE_ROLES[\s\S]*"student"[\s\S]*"academic_lead"/);
  assert.doesNotMatch(source.match(/const PROVISIONABLE_ROLES[\s\S]*?\];/)?.[0] ?? "", /platform_admin|organization_admin|site_admin/);
});

test("invitation provisioning rejects cross-tenant sites and invalid role scopes", () => {
  assert.match(source, /site\.organization_id !== organizationId/);
  assert.match(source, /roleValue === "academic_lead" && siteId/);
});

test("invitation provisioning cleans up failed invitations and preserves the admin audit actor", () => {
  assert.match(source, /if \(invitedUserId && adminClient\)/);
  assert.match(source, /supabase\.from\("role_assignments"\)\.insert/);
});
