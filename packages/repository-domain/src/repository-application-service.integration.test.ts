import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Pool } from 'pg';
import { runMigrations } from './migrate';
import { PostgresRepositoryStore } from './postgres-repository';
import {
  DefaultRepositoryApplicationService,
  InMemoryDomainEventPublisher,
} from './repository-application-service';

const databaseUrl = process.env.DATABASE_URL;
const describeWithDatabase = databaseUrl ? describe : describe.skip;

describeWithDatabase('Repository application service PostgreSQL lifecycle', () => {
  const pool = new Pool({ connectionString: databaseUrl });
  const store = new PostgresRepositoryStore(pool);
  const publisher = new InMemoryDomainEventPublisher();
  const service = new DefaultRepositoryApplicationService(store, publisher);

  beforeAll(async () => {
    await runMigrations(databaseUrl!);
  });

  beforeEach(async () => {
    await pool.query('TRUNCATE TABLE repositories');
    publisher.clear();
  });

  afterAll(async () => {
    await pool.end();
  });

  it('executes the complete command lifecycle and publishes post-commit events', async () => {
    await service.create({
      id: 'repo-001',
      tenantId: 'tenant-001',
      name: 'master-blueprint',
      displayName: 'MAC Enterprise Master Blueprint',
      type: 'MASTER_BLUEPRINT',
      owner: { userId: 'user-001', displayName: 'George Juste' },
      now: new Date('2026-08-06T12:00:00.000Z'),
    });

    await service.update({
      tenantId: 'tenant-001',
      repositoryId: 'repo-001',
      displayName: 'Updated Master Blueprint',
      visibility: 'ENTERPRISE',
      now: new Date('2026-08-07T12:00:00.000Z'),
    });

    await service.archive({
      tenantId: 'tenant-001',
      repositoryId: 'repo-001',
      now: new Date('2026-08-08T12:00:00.000Z'),
    });

    await service.restore({
      tenantId: 'tenant-001',
      repositoryId: 'repo-001',
      now: new Date('2026-08-09T12:00:00.000Z'),
    });

    const loaded = await store.findById('tenant-001', 'repo-001');
    expect(loaded?.snapshot).toMatchObject({
      displayName: 'Updated Master Blueprint',
      visibility: 'ENTERPRISE',
      status: 'ACTIVE',
    });
    expect(loaded?.pullDomainEvents()).toEqual([]);

    await service.delete({
      tenantId: 'tenant-001',
      repositoryId: 'repo-001',
      now: new Date('2026-08-10T12:00:00.000Z'),
    });

    expect(await store.findById('tenant-001', 'repo-001')).toBeNull();
    expect(publisher.events.map((event) => event.type)).toEqual([
      'RepositoryCreated',
      'RepositoryUpdated',
      'RepositoryArchived',
      'RepositoryRestored',
      'RepositoryDeleted',
    ]);
  });

  it('rolls back persistence and publishes no events when a transaction fails', async () => {
    const failingService = new DefaultRepositoryApplicationService(
      {
        async execute<T>(work: Parameters<PostgresRepositoryStore['execute']>[0]): Promise<T> {
          return store.execute(async (transactionalStore) => {
            const result = await work(transactionalStore);
            throw new Error('forced rollback');
          });
        },
      },
      publisher,
    );

    await expect(
      failingService.create({
        id: 'repo-rollback',
        tenantId: 'tenant-001',
        name: 'rollback-repository',
        displayName: 'Rollback Repository',
        type: 'ENGINEERING',
        owner: { userId: 'user-001', displayName: 'George Juste' },
      }),
    ).rejects.toThrow('forced rollback');

    expect(await store.findById('tenant-001', 'repo-rollback')).toBeNull();
    expect(publisher.events).toEqual([]);
  });
});
