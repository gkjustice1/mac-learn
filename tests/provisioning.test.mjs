import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const source = await readFile(new URL("../src/app/actions.ts", import.meta.url), "utf8");
const invitationPage = await readFile(
  new URL("../src/app/platform/invitations/new/page.tsx", import.meta.url),
  "utf8"
);
const invitationForm = await readFile(
  new URL("../src/app/platform/invitations/new/InvitationForm.tsx", import.meta.url),
  "utf8"
);
const accessRolesPage = await readFile(
  new URL("../src/app/platform/access-roles/page.tsx", import.meta.url),
  "utf8"
);

test("invitation provisioning is server-only and organization-scoped", () => {
  assert.match(source, /"use server"/);
  assert.match(source, /await requireOrganizationAdmin\(organizationId\)/);
  assert.match(source, /\.eq\("status", "active"\)/);
  assert.match(source, /inviteUserByEmail/);
  assert.match(source, /redirectTo: `\$\{appUrl\}\/auth\/callback`/);
  assert.match(source, /mac_create_invited_enterprise_identity/);
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
  const provisionInvitationSource = source.match(
    /export async function provisionInvitation[\s\S]*?\n}\n\nfunction getSupportedLocales/
  )?.[0] ?? "";

  assert.match(provisionInvitationSource, /mac_cleanup_invited_enterprise_identity/);
  assert.match(provisionInvitationSource, /if \(invitedUserId && adminClient\)/);
  assert.doesNotMatch(provisionInvitationSource, /invitedUserId && personId/);
  assert.ok(
    provisionInvitationSource.indexOf("mac_cleanup_invited_enterprise_identity") <
      provisionInvitationSource.indexOf("deleteUser(invitedUserId)")
  );
  assert.doesNotMatch(provisionInvitationSource, /\.from\("(?:people|users|profiles)"\)/);
  assert.match(source, /supabase\.from\("role_assignments"\)\.insert/);
});

test("platform administration exposes an authorized invitation form", () => {
  assert.match(accessRolesPage, /href="\/platform\/invitations\/new"/);
  assert.match(invitationPage, /await requirePlatformAdmin\(\)/);
  assert.match(invitationForm, /useActionState\(provisionInvitation/);
  assert.match(invitationForm, /searchRoleAssignmentOptions/);
  assert.match(invitationForm, /organizationId/);
  assert.match(invitationForm, /name="first_name"/);
  assert.match(invitationForm, /name="last_name"/);
  assert.match(invitationForm, /name="email"/);
  assert.match(invitationForm, /name="organization_id"/);
  assert.match(invitationForm, /name="site_id"/);
  assert.match(invitationForm, /name="role_key"/);
  assert.match(invitationForm, /aria-label={`\$\{label\} selection`}/);
});

test("invitation form only exposes roles supported by server provisioning", () => {
  assert.match(invitationForm, /value: "student"/);
  assert.match(invitationForm, /value: "guardian"/);
  assert.match(invitationForm, /value: "tutor"/);
  assert.match(invitationForm, /value: "teacher"/);
  assert.match(invitationForm, /value: "academic_lead"/);
  assert.doesNotMatch(
    invitationForm.match(/const ROLE_OPTIONS[\s\S]*?as const;/)?.[0] ?? "",
    /platform_admin|platform_support|organization_admin|site_admin/
  );
});

test("invitation form preserves identity fields after a failed submission", () => {
  assert.match(invitationForm, /const \[firstName, setFirstName\] = useState\(""\)/);
  assert.match(invitationForm, /const \[lastName, setLastName\] = useState\(""\)/);
  assert.match(invitationForm, /const \[email, setEmail\] = useState\(""\)/);
  assert.match(invitationForm, /value={firstName}/);
  assert.match(invitationForm, /value={lastName}/);
  assert.match(invitationForm, /value={email}/);
});
