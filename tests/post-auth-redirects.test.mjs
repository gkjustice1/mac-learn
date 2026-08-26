import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const postAuthActions = [
  "src/app/login/actions.ts",
  "src/app/update-password/actions.ts",
];

for (const actionPath of postAuthActions) {
  test(`${actionPath} redirects completed authentication to the dashboard`, async () => {
    const source = await readFile(actionPath, "utf8");

    assert.match(source, /redirect\("\/dashboard"\);/);
    assert.doesNotMatch(source, /redirect\("\/"\);/);
  });
}
