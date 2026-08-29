import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const proxySource = await readFile(
  new URL("../src/lib/supabase/proxy.ts", import.meta.url),
  "utf8"
);
const updatePasswordSource = await readFile(
  new URL("../src/app/update-password/actions.ts", import.meta.url),
  "utf8"
);

test("invited sessions are redirected to password setup before workspace access", () => {
  assert.match(proxySource, /\.from\("users"\)/);
  assert.match(proxySource, /\.select\("account_status"\)/);
  assert.match(proxySource, /identity\?\.account_status === "invited"/);
  assert.match(proxySource, /pathname !== "\/update-password"/);
  assert.match(proxySource, /passwordSetupUrl\.pathname = "\/update-password"/);
});

test("password creation succeeds before an invited enterprise identity is activated", () => {
  const passwordUpdateIndex = updatePasswordSource.indexOf(
    "supabase.auth.updateUser"
  );
  const activationIndex = updatePasswordSource.indexOf(
    "mac_activate_invited_enterprise_user"
  );

  assert.ok(passwordUpdateIndex >= 0);
  assert.ok(activationIndex > passwordUpdateIndex);
  assert.match(
    updatePasswordSource,
    /identity\?\.account_status === "invited"/
  );
  assert.match(
    updatePasswordSource,
    /if \(activationError \|\| !activated\)/
  );
  assert.match(updatePasswordSource, /await supabase\.auth\.signOut\(\)/);
  assert.match(updatePasswordSource, /redirect\("\/dashboard"\)/);
});

test("enterprise lookup absence or errors do not block legacy password recovery", () => {
  assert.match(updatePasswordSource, /const \{ data: identity \} = await supabase/);
  assert.doesNotMatch(updatePasswordSource, /identityError/);
  assert.match(
    updatePasswordSource,
    /if \(identity\?\.account_status === "invited"\)/
  );
});
