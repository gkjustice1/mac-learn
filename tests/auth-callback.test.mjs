import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const source = await readFile(
  new URL("../src/app/auth/callback/route.ts", import.meta.url),
  "utf8"
);

test("the auth callback activates invited users after invite-link verification", () => {
  assert.match(source, /type !== "recovery" && type !== "invite"/);
  assert.match(source, /if \(type === "invite"\)/);
  assert.match(source, /mac_activate_invited_enterprise_user/);
  assert.match(source, /new URL\("\/dashboard", requestUrl\.origin\)/);
});
