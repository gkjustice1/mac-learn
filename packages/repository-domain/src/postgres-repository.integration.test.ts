import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Pool } from 'pg';
import { runMigrations } from './migrate';
import { PostgresRepositoryStore } from './postgres-repository';
import { Repository } from './repository';

const databaseUrl = process.env.DATABASE_URL;
const describeWithDatabase = databaseUrl ? describe : describe.skip;

describeWithDatabase('PostgresRepositoryStore', () => {
  const pool = new Pool({ connectionString: databaseUrl });
  const store = new PostgresRepositoryStore(pool);

  beforeAll(async () => {
    await runMigrations(databaseUrl!);
  });

  beforeEach(async () => {
    await pool.query('TRUNCATE TABLE repositories');
  });

  afterAll(async () => {
    await pool.end();
  });

  function createRepository(id = 'repo-001', tenantId = 'tenant-001') {
    return Repository.create({
      id,
      tenantId,
      name: `repository-${id}`,
      displayName: `Repository ${id}`,
      description: 'Repository persistence integration test',
      type: 'ENGINEERING',
      visibility: 'TENANT',
      classification: 'CONFIDENTIAL',
      owner: { userId: 'user-001', displayName: 'George Juste' },
      now: new Date('2026-08-06T12:00:00.000Z'),
    });
  }

  it('saves and rehydrates a repository aggregate', async () => {
    const repository = createRepository();
    await store.save(repository);

    const loaded = await store.findById('tenant-001', 'repo-001');

    expect(loaded).not.toBeNull();
    expect(loaded?.snapshot).toEqual(repository.snapshot);
    expect(loaded?.pullDomainEvents()).toEqual([]);
  });

  it('updates an existing repository through upsert semantics', async () => {
    const repository = createRepository();
    await store.save(repository);

    repository.update({
      displayName: 'Updated Repository',
      visibility: 'ENTERPRISE',
      now: new Date('2026-08-07T12:00:00.000Z'),
    });
    await store.save(repository);

    const loaded = await store.findById('tenant-001', 'repo-001');
    expect(loaded?.snapshot.displayName).toBe('Updated Repository');
    expect(loaded?.snapshot.visibility).toBe('ENTERPRISE');
    expect(loaded?.snapshot.updatedAt).toEqual(new Date('2026-08-07T12:00:00.000Z'));
  });

  it('isolates repositories by tenant', async () => {
    await store.save(createRepository('repo-001', 'tenant-001'));
    await store.save(createRepository('repo-001', 'tenant-002'));

    const tenantOne = await store.listByTenant('tenant-001');
    const tenantTwo = await store.listByTenant('tenant-002');

    expect(tenantOne).toHaveLength(1);
    expect(tenantOne[0]?.tenantId).toBe('tenant-001');
    expect(tenantTwo).toHaveLength(1);
    expect(tenantTwo[0]?.tenantId).toBe('tenant-002');
  });

  it('persists archived lifecycle state and restores it', async () => {
    const repository = createRepository();
    repository.archive(new Date('2026-08-08T12:00:00.000Z'));
    await store.save(repository);

    const archived = await store.findById('tenant-001', 'repo-001');
    expect(archived?.snapshot.status).toBe('ARCHIVED');
    expect(archived?.snapshot.archivedAt).toEqual(new Date('2026-08-08T12:00:00.000Z'));

    archived?.restore(new Date('2026-08-09T12:00:00.000Z'));
    await store.save(archived!);

    const restored = await store.findById('tenant-001', 'repo-001');
    expect(restored?.snapshot.status).toBe('ACTIVE');
    expect(restored?.snapshot.archivedAt).toBeUndefined();
  });

  it('deletes only the requested tenant repository', async () => {
    await store.save(createRepository('repo-001', 'tenant-001'));
    await store.save(createRepository('repo-001', 'tenant-002'));

    expect(await store.delete('tenant-001', 'repo-001')).toBe(true);
    expect(await store.findById('tenant-001', 'repo-001')).toBeNull();
    expect(await store.findById('tenant-002', 'repo-001')).not.toBeNull();
    expect(await store.delete('tenant-001', 'missing')).toBe(false);
  });
});
