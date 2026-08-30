import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const migration = await readFile(
  "supabase/migrations/20260829235710_grant_tutor_authenticated_read_access.sql",
  "utf8"
);
const databaseTest = await readFile(
  "supabase/tests/tutor_authenticated_read_grants.test.sql",
  "utf8"
);

const tutorReadTables = [
  "students",
  "sessions",
  "subjects",
  "tutor_availability",
  "session_notes",
  "progress_reports",
];

test("Tutor workspace tables receive authenticated SELECT only", () => {
  assert.match(migration, /grant select on table[\s\S]*to authenticated;/);
  assert.doesNotMatch(
    migration,
    /grant\s+(?:insert|update|delete|all)|grant[^;]*(?:insert|update|delete)/i
  );

  for (const table of tutorReadTables) {
    assert.match(migration, new RegExp(`public\\.${table}\\b`));
  }
});

test("Tutor workspace tables remain unavailable to anonymous users", () => {
  assert.match(migration, /revoke select on table[\s\S]*from anon;/);

  for (const table of tutorReadTables) {
    assert.match(
      databaseTest,
      new RegExp(`not has_table_privilege\\('anon', 'public\\.${table}', 'select'\\)`)
    );
  }
});

test("database regression coverage verifies authenticated grants and RLS", () => {
  for (const table of tutorReadTables) {
    assert.match(
      databaseTest,
      new RegExp(`has_table_privilege\\('authenticated', 'public\\.${table}', 'select'\\)`)
    );
  }

  assert.match(databaseTest, /and relrowsecurity/);
  assert.match(databaseTest, /6::bigint/);
});
