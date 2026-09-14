import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const route = await readFile(
  new URL("../src/app/audio/[grade]/[lesson]/[asset]/route.ts", import.meta.url),
  "utf8"
);

test("MAC READS audio resolver only serves published registry assets", () => {
  assert.match(route, /\.eq\("status", "published"\)/);
  assert.match(route, /createSignedUrl\(audioAsset\.storage_path/);
  assert.match(route, /Response\.redirect\(signed\.signedUrl, 307\)/);
});

test("MAC READS audio resolver uses stable grade, lesson, and asset route keys", () => {
  assert.match(route, /\.eq\("grade_slug", grade\)/);
  assert.match(route, /\.eq\("lesson_slug", lesson\)/);
  assert.match(route, /\.eq\("public_slug", asset\)/);
});
