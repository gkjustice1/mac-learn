import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const callbackSource = await readFile(
  new URL("../src/app/auth/callback/route.ts", import.meta.url),
  "utf8"
);
const configSource = await readFile(
  new URL("../supabase/config.toml", import.meta.url),
  "utf8"
);
const inviteTemplate = await readFile(
  new URL("../supabase/templates/invite.html", import.meta.url),
  "utf8"
);

test("the invite template sends the token hash and invite type to the callback", () => {
  assert.match(configSource, /\[auth\.email\.template\.invite\]/);
  assert.match(configSource, /content_path = "\.\/supabase\/templates\/invite\.html"/);
  assert.match(inviteTemplate, /\{\{ \.RedirectTo \}\}/);
  assert.match(inviteTemplate, /token_hash=\{\{ \.TokenHash \}\}/);
  assert.match(inviteTemplate, /type=invite/);
});

test("the auth callback activates invited users after invite-link verification", () => {
  assert.match(callbackSource, /type !== "recovery" && type !== "invite"/);
  assert.match(callbackSource, /if \(type === "invite"\)/);
  assert.match(callbackSource, /mac_activate_invited_enterprise_user/);
});

test("invited users must set a password before entering the dashboard", () => {
  const inviteBranch = callbackSource.match(
    /if \(type === "invite"\)[\s\S]*?return NextResponse\.redirect\([\s\S]*?\n  \}/
  )?.[0] ?? "";

  assert.match(inviteBranch, /\/update-password\?onboarding=invite/);
  assert.doesNotMatch(inviteBranch, /new URL\("\/dashboard"/);
});
