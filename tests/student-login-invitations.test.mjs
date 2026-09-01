import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("Student login invitation uses the existing canonical enrollment", async () => {
  const [action, migration] = await Promise.all([
    read("src/app/platform/students/actions.ts"),
    read("supabase/migrations/20260901090000_invite_existing_student_login.sql"),
  ]);
  assert.match(action, /await requirePlatformAdmin\(\)/);
  assert.match(action, /inviteUserByEmail\(email/);
  assert.match(action, /\.rpc\("mac_admin_link_invited_student_login"/);
  assert.match(migration, /v_student\.person_id/);
  assert.match(migration, /insert into public\.users \(id, person_id, account_status\)/);
  assert.match(migration, /values \(p_user_id, v_student\.person_id, 'invited'\)/);
  assert.doesNotMatch(migration, /insert into public\.people/);
});

test("Student invitation scope and duplicate protections are enforced in the transaction", async () => {
  const migration = await read("supabase/migrations/20260901090000_invite_existing_student_login.sql");
  assert.match(migration, /not public\.mac_is_platform_admin\(\)/);
  assert.match(migration, /site\.organization_id = v_student\.organization_id/);
  assert.match(migration, /v_student\.primary_site_id, 'student', 'active'/);
  assert.match(migration, /app_user\.person_id = v_student\.person_id/);
  assert.match(migration, /lower\(profile\.email\) = v_auth_email/);
  assert.match(migration, /student enrollment is not current/);
  assert.match(migration, /login_invited/);
  assert.match(migration, /revoke all on function public\.mac_admin_link_invited_student_login\(uuid, uuid, text\) from public, anon/);
});

test("Failed database linking removes only the newly invited Auth identity", async () => {
  const action = await read("src/app/platform/students/actions.ts");
  assert.match(action, /if \(invitedUserId\)/);
  assert.match(action, /auth\.admin\.deleteUser\(invitedUserId\)/);
  assert.doesNotMatch(action, /mac_cleanup_invited_enterprise_identity[\s\S]*inviteExistingStudentLogin/);
});

test("Platform Students exposes a dedicated invitation form with immutable scope", async () => {
  const [list, page, form] = await Promise.all([
    read("src/app/platform/students/page.tsx"),
    read("src/app/platform/students/[studentId]/invite/page.tsx"),
    read("src/app/platform/students/[studentId]/invite/StudentLoginInvitationForm.tsx"),
  ]);
  assert.match(list, /Invite login/);
  assert.match(page, /await requirePlatformAdmin\(\)/);
  assert.match(form, /type="hidden" name="student_id"/);
  assert.doesNotMatch(form, /name="organization_id"|name="site_id"|name="person_id"|name="role_key"/);
});
