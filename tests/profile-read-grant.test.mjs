import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const migration = await readFile(
  "supabase/migrations/20260830001115_grant_authenticated_profile_read_access.sql",
  "utf8"
);
const databaseTest = await readFile(
  "supabase/tests/authenticated_profile_read_grant.test.sql",
  "utf8"
);

test("profiles receive authenticated SELECT without write escalation", () => {
  assert.match(
    migration,
    /grant select on table public\.profiles to authenticated;/
  );
  assert.match(
    migration,
    /revoke select on table public\.profiles from anon;/
  );
  assert.doesNotMatch(
    migration,
    /grant\s+(?:insert|update|delete|all)|grant[^;]*(?:insert|update|delete)/i
  );
});

test("profile grant coverage preserves owner-only RLS", () => {
  assert.match(databaseTest, /has_table_privilege\('authenticated'/);
  assert.match(databaseTest, /not has_table_privilege\('anon'/);
  assert.match(databaseTest, /relrowsecurity/);
  assert.match(databaseTest, /an authenticated user can see their own profile/);
  assert.match(databaseTest, /an authenticated user cannot see another profile/);
});
