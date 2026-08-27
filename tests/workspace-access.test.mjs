import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("the root route enters the authenticated dashboard", async () => {
  const source = await readFile("src/app/page.tsx", "utf8");

  assert.match(source, /redirect\("\/dashboard"\)/);
  assert.doesNotMatch(source, /nextjs\.org|vercel\.com\/templates/);
});

test("the enterprise workspace requires an operational role", async () => {
  const source = await readFile("src/app/enterprise/page.tsx", "utf8");

  assert.match(source, /requireAnyRole\(ENTERPRISE_WORKSPACE_ROLES\)/);
  assert.doesNotMatch(source, /requireEnterpriseUser/);
});

test("dashboard routing uses the shared role-workspace resolver", async () => {
  const source = await readFile("src/app/dashboard/page.tsx", "utf8");

  assert.match(source, /resolveWorkspacePath\(primaryAssignment\)/);
});
