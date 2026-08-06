import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Pool } from 'pg';
import { runMigrations } from './migrate';
import { PostgresRepositoryStore } from './postgres-repository';
import {
  DefaultRepositoryApplicationService,
  InMemoryDomainEventPublisher,
} from './repository-application-service';
import type {
  ApiPrincipal,
  ListRepositoriesQuery,
  RepositoryApiDependencies,
  RepositoryDto,
} from './repository-api-contracts';
import {
  createRepositoryGraphqlResolvers,
  createRepositoryRestController,
} from './repository-api';
import type { Repository } from './repository';

const databaseUrl = process.env.DATABASE_URL;
const describeWithDatabase = databaseUrl ? describe : describe.skip;

function toDto(repository: Repository): RepositoryDto {
  const snapshot = repository.snapshot;
  return {
    ...snapshot,
    createdAt: snapshot.createdAt.toISOString(),
    updatedAt: snapshot.updatedAt.toISOString(),
    archivedAt: snapshot.archivedAt?.toISOString(),
  };
}

const principal: ApiPrincipal = {
  subject: 'user-001',
  tenantId: 'tenant-001',
  roles: ['repository-admin'],
  permissions: [
    'repository:create', 'repository:read', 'repository:update',
    'repository:archive', 'repository:restore', 'repository:delete',
  ],
};

describeWithDatabase('Repository API PostgreSQL integration', () => {
  const pool = new Pool({ connectionString: databaseUrl });
  const store = new PostgresRepositoryStore(pool);
  const commands = new DefaultRepositoryApplicationService(
    store,
    new InMemoryDomainEventPublisher(),
  );
  const dependencies: RepositoryApiDependencies = {
    commands,
    queries: {
      async get(tenantId, repositoryId) {
        const repository = await store.findById(tenantId, repositoryId);
        return repository ? toDto(repository) : null;
      },
      async list(tenantId, query: ListRepositoriesQuery) {
        let repositories = await store.listByTenant(tenantId);
        if (query.status) repositories = repositories.filter((item) => item.status === query.status);
        if (query.type) repositories = repositories.filter((item) => item.type === query.type);
        if (query.visibility) repositories = repositories.filter((item) => item.visibility === query.visibility);
        const limit = Math.max(1, Math.min(query.limit ?? 100, 100));
        return { items: repositories.slice(0, limit).map(toDto) };
      },
    },
  };

  beforeAll(async () => {
    await runMigrations(databaseUrl!);
  });

  beforeEach(async () => {
    await pool.query('TRUNCATE TABLE repositories');
  });

  afterAll(async () => {
    await pool.end();
  });

  it('executes the complete lifecycle through REST controllers', async () => {
    const controller = createRepositoryRestController(dependencies);
    const baseRequest = {
      principal,
      params: {},
      query: {},
      body: {},
      correlationId: 'rest-correlation',
    };

    const created = await controller.create({
      ...baseRequest,
      body: {
        id: 'repo-rest',
        name: 'rest-repository',
        displayName: 'REST Repository',
        type: 'ENGINEERING',
        visibility: 'TENANT',
        owner: { userId: 'user-001', displayName: 'George Juste' },
      },
    });
    expect(created.status).toBe(201);

    const updated = await controller.update({
      ...baseRequest,
      params: { repositoryId: 'repo-rest' },
      body: { displayName: 'REST Repository Updated', visibility: 'ENTERPRISE' },
    });
    expect(updated.status).toBe(200);

    expect((await controller.archive({ ...baseRequest, params: { repositoryId: 'repo-rest' } })).status).toBe(200);
    expect((await controller.restore({ ...baseRequest, params: { repositoryId: 'repo-rest' } })).status).toBe(200);

    const fetched = await controller.get({ ...baseRequest, params: { repositoryId: 'repo-rest' } });
    expect(fetched.status).toBe(200);
    expect(fetched.body).toMatchObject({ displayName: 'REST Repository Updated', status: 'ACTIVE' });

    const listed = await controller.list({ ...baseRequest, query: { type: 'ENGINEERING' as const } });
    expect(listed.status).toBe(200);
    expect((listed.body as { items: RepositoryDto[] }).items).toHaveLength(1);

    expect((await controller.delete({ ...baseRequest, params: { repositoryId: 'repo-rest' } })).status).toBe(204);
    expect(await store.findById('tenant-001', 'repo-rest')).toBeNull();
  });

  it('executes the complete lifecycle through GraphQL resolvers', async () => {
    const resolvers = createRepositoryGraphqlResolvers(dependencies);
    const context = { principal };

    await resolvers.Mutation.createRepository(null, {
      input: {
        id: 'repo-graphql',
        name: 'graphql-repository',
        displayName: 'GraphQL Repository',
        type: 'RESEARCH',
        owner: { userId: 'user-001', displayName: 'George Juste' },
      },
    }, context);

    await resolvers.Mutation.updateRepository(null, {
      id: 'repo-graphql',
      input: { displayName: 'GraphQL Repository Updated' },
    }, context);
    await resolvers.Mutation.archiveRepository(null, { id: 'repo-graphql' }, context);
    await resolvers.Mutation.restoreRepository(null, { id: 'repo-graphql' }, context);

    const fetched = await resolvers.Query.repository(null, { id: 'repo-graphql' }, context);
    expect(fetched).toMatchObject({ displayName: 'GraphQL Repository Updated', status: 'ACTIVE' });

    const listed = await resolvers.Query.repositories(null, { type: 'RESEARCH' }, context);
    expect(listed.items).toHaveLength(1);

    expect(await resolvers.Mutation.deleteRepository(null, { id: 'repo-graphql' }, context)).toBe(true);
    expect(await store.findById('tenant-001', 'repo-graphql')).toBeNull();
  });

  it('preserves tenant isolation through both transports', async () => {
    await commands.create({
      id: 'shared-id', tenantId: 'tenant-002', name: 'other-tenant',
      displayName: 'Other Tenant Repository', type: 'OPERATIONS',
      owner: { userId: 'user-002', displayName: 'Other User' },
    });

    const controller = createRepositoryRestController(dependencies);
    const response = await controller.get({
      principal,
      params: { repositoryId: 'shared-id' },
      query: {},
      body: {},
      correlationId: 'tenant-isolation',
    });
    expect(response.status).toBe(404);

    const resolvers = createRepositoryGraphqlResolvers(dependencies);
    expect(await resolvers.Query.repository(null, { id: 'shared-id' }, { principal })).toBeNull();
  });
});
