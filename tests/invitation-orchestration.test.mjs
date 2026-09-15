import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import test from 'node:test';
import ts from 'typescript';

// Execute the real server-action module, replacing only framework/Auth/Data API boundaries.
// This does not claim live email delivery or browser acceptance coverage.
const source = await readFile(new URL('../src/app/actions.ts', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022,
} }).outputText;

function harness(options = {}) {
  const calls = [];
  const org = 'org-one';
  const client = { from(table) {
    const query = {
      select() { return query; }, eq() { return query; },
      async maybeSingle() { return { data: table === 'organizations' ? { id: org } :
        { id: 'site-one', organization_id: options.crossTenant ? 'other-org' : org, status: 'active' }, error: null }; },
      async insert(row) { calls.push(['assign', row]); return { error: options.roleError ? { message: 'role failed' } : null }; },
    };
    return query;
  } };
  const admin = {
    auth: { admin: {
      async inviteUserByEmail(email, config) {
        calls.push(['invite', email, config]);
        return options.authError ? { data: {}, error: { message: 'mail failed' } } : { data: { user: { id: 'new-user' } }, error: null };
      },
      async deleteUser(id) { calls.push(['delete', id]); return { error: null }; },
    } },
    async rpc(name, args) {
      calls.push([name, args]);
      if (name === 'mac_create_invited_enterprise_identity') return { data: options.identityError ? null : 'new-person', error: options.identityError ? { message: 'identity failed' } : null };
      if (name === 'mac_cleanup_invited_enterprise_identity') return { data: options.cleanupStatus ?? 'cleaned', error: options.cleanupError ? { message: 'cleanup failed' } : null };
      throw new Error(`Unexpected RPC: ${name}`);
    },
  };
  const dependencies = {
    'next/cache': { revalidatePath() {} }, 'next/navigation': { redirect() { throw new Error('unexpected redirect'); } },
    '@/lib/auth/authorization': { async requireOrganizationAdmin(id) { calls.push(['authorize', id]); if (options.denied) throw new Error('denied'); } },
    '@/lib/supabase/admin': { createAdminClient: () => admin },
    '@/lib/supabase/server': { createClient: async () => client },
  };
  const exports = {};
  vm.runInNewContext(compiled, { exports, process: { env: { NEXT_PUBLIC_APP_URL: 'https://example.test' } },
    require(name) { assert.ok(name in dependencies, `Unexpected import ${name}`); return dependencies[name]; } });
  const form = new FormData();
  for (const [key, value] of Object.entries({ email: 'INVITE@example.test', first_name: 'Test', last_name: 'Invite', organization_id: org, site_id: 'site-one', role_key: 'tutor' })) form.set(key, value);
  return { calls, run: () => exports.provisionInvitation({ error: null, invited: false }, form) };
}

test('successful invitation authorizes, sends Auth invite, creates identity and assigns role in order', async () => {
  const h = harness(); const result = await h.run();
  assert.equal(result.invited, true);
  assert.deepEqual(h.calls.map(c => c[0]), ['authorize', 'invite', 'mac_create_invited_enterprise_identity', 'assign']);
  assert.equal(h.calls[1][1], 'invite@example.test');
  assert.equal(h.calls[1][2].redirectTo, 'https://example.test/auth/callback');
  assert.equal(h.calls[2][1].p_user_id, 'new-user');
  assert.equal(h.calls[3][1].user_id, 'new-user');
  assert.equal(h.calls[3][1].organization_id, 'org-one');
});
for (const options of [{ denied: true }, { crossTenant: true }]) test(`scope rejection prevents Auth invitation: ${JSON.stringify(options)}`, async () => {
  const h = harness(options); assert.equal((await h.run()).invited, false);
  assert.deepEqual(h.calls.map(c => c[0]), ['authorize']);
});
test('Auth failure creates no identity or cleanup request', async () => {
  const h = harness({ authError: true }); assert.equal((await h.run()).invited, false);
  assert.deepEqual(h.calls.map(c => c[0]), ['authorize', 'invite']);
});
for (const failure of ['identityError', 'roleError']) {
  for (const cleanupStatus of ['cleaned', 'missing', 'not_invited']) test(`${failure}: cleanup ${cleanupStatus} controls Auth deletion`, async () => {
    const h = harness({ [failure]: true, cleanupStatus }); assert.equal((await h.run()).invited, false);
    const names = h.calls.map(c => c[0]);
    assert.ok(names.includes('mac_cleanup_invited_enterprise_identity'));
    assert.equal(names.includes('delete'), cleanupStatus !== 'not_invited');
    if (names.includes('delete')) assert.ok(names.indexOf('mac_cleanup_invited_enterprise_identity') < names.indexOf('delete'));
    if (failure === 'identityError') assert.ok(!names.includes('assign'));
  });
}
test('cleanup RPC error preserves Auth identity for recovery', async () => {
  const h = harness({ roleError: true, cleanupError: true }); assert.equal((await h.run()).invited, false);
  assert.ok(!h.calls.some(c => c[0] === 'delete'));
});
