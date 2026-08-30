import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const actions = fs.readFileSync("src/app/platform/students/actions.ts", "utf8");
const form = fs.readFileSync("src/app/platform/students/new/StudentEnrollmentForm.tsx", "utf8");
const page = fs.readFileSync("src/app/platform/students/new/page.tsx", "utf8");
const migration = fs.readFileSync("supabase/migrations/20260830173035_add_student_enrollment_workflow.sql", "utf8");

test("student enrollment is restricted and transactionally audited", () => {
  assert.match(actions, /requireOrganizationAdmin\(organizationId\)/);
  assert.match(actions, /mac_admin_enroll_student/);
  assert.match(migration, /security definer/);
  assert.match(migration, /not public\.mac_is_organization_admin\(p_organization_id\)/);
  assert.match(migration, /insert into public\.student_enrollment_events/);
  assert.match(migration, /student_id uuid not null references public\.students\(id\) on delete restrict/);
  assert.match(migration, /on conflict \(organization_id, person_id\)[\s\S]*do nothing/);
  assert.match(migration, /guardian\.status = 'active'/);
  assert.match(migration, /must be reactivated separately/);
  assert.match(migration, /revoke insert, update, delete.*authenticated/s);
});

test("student enrollment validates tenant, site, and guardian scope", () => {
  assert.match(migration, /site\.organization_id = p_organization_id/);
  assert.match(migration, /assignment\.organization_id = p_organization_id/);
  assert.match(migration, /assignment\.site_id is null or assignment\.site_id = p_site_id/);
  assert.match(migration, /enterprise_user\.account_status in \('invited', 'active'\)/);
  assert.match(migration, /p_enterprise_status is null or p_enterprise_status not in/);
  assert.match(migration, /p_relationship_type is null[\s\S]*p_relationship_type not in \('parent_guardian', 'parent', 'guardian', 'caregiver'\)/);
  assert.match(migration, /now\(\) at time zone v_site_timezone/);
  assert.match(migration, /Enrollment start date cannot be in the future/);
  assert.match(migration, /values \(\s*null,\s*btrim\(p_first_name\)/);
  assert.match(migration, /alter column parent_id drop not null/);
  assert.match(migration, /foreign key \(parent_id\) references public\.profiles\(id\) on delete set null/);
  assert.match(migration, /guardian_student_relationships\.valid_from <= coalesce\(\(now\(\) at time zone site\.timezone\)::date, current_date\)/);
  assert.match(migration, /relationship\.valid_from <= coalesce\(\(now\(\) at time zone site\.timezone\)::date, current_date\)/);
  assert.match(actions, /site_id\.is\.null,site_id\.eq\.\$\{siteId\}/);
  assert.match(actions, /valid_until\.is\.null,valid_until\.gt\.\$\{now\}/);
  assert.match(actions, /role_assignments\.valid_from", now/);
  assert.match(actions, /profiles!inner\(organization_id\)/);
  assert.match(actions, /user\.profiles\.organization_id", organizationId/);
  assert.match(form, /siteId=\{siteId\}/);
  assert.match(form, /key=\{`site-\$\{organizationId\}`\}/);
  assert.match(form, /key=\{`guardian-\$\{organizationId\}-\$\{siteId\}`\}/);
});

test("failed new-guardian enrollment cleans up only an invited identity", () => {
  assert.match(actions, /mac_cleanup_invited_enterprise_identity/);
  assert.match(actions, /cleanupStatus === "cleaned" \|\| cleanupStatus === "missing"/);
  assert.match(actions, /deleteUser\(invitedGuardianUserId\)/);
});

test("organization and site are validated before sending a guardian invitation", () => {
  assert.match(actions, /from\("organizations"\)[\s\S]*eq\("status", "active"\)/);
  assert.match(actions, /from\("sites"\)[\s\S]*eq\("organization_id", organizationId\)[\s\S]*eq\("status", "active"\)/);
  assert.ok(actions.indexOf("const [organizationCheck, siteCheck]") < actions.indexOf("inviteUserByEmail"));
  assert.ok(actions.indexOf("businessToday") < actions.indexOf("inviteUserByEmail"));
  assert.match(actions, /kind === "guardian" \? createAdminClient\(\) : await createClient\(\)/);
});

test("controlled fields preserve data across unsuccessful submissions", () => {
  assert.match(form, /value=\{fields\[name\]\}/);
  for (const name of ["grade_level", "school_name", "guardian_first_name", "guardian_last_name", "guardian_email"]) {
    assert.match(form, new RegExp(`value=\\{fields\\.${name}\\}`));
  }
  assert.match(form, /useActionState\(enrollStudent/);
  assert.match(form, /state\.active \? " The active student is now available in Tutor operations\."/);
});

test("student enrollment is exposed only from the protected administrator page", () => {
  assert.match(page, /requirePlatformAdmin\(\)/);
  assert.match(page, /StudentEnrollmentForm/);
  assert.match(form, /aria-label=\{`\$\{label\} selection`\}/);
});
