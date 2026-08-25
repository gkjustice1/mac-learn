import assert from "node:assert/strict";
import test from "node:test";

import { resolveSupabaseSecretKey } from "../src/lib/supabase/resolve-secret-key.mjs";

test("uses the legacy service-role key when the preferred secret is blank", () => {
  assert.equal(
    resolveSupabaseSecretKey("   ", " legacy-service-role-key "),
    "legacy-service-role-key"
  );
});

test("prefers and trims the new secret key", () => {
  assert.equal(
    resolveSupabaseSecretKey(" new-secret-key ", "legacy-service-role-key"),
    "new-secret-key"
  );
});

test("returns undefined when neither key is configured", () => {
  assert.equal(resolveSupabaseSecretKey("", "  "), undefined);
});
