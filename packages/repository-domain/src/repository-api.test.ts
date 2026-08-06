import { describe, expect, it } from 'vitest';
import { Repository } from './repository';
import type { RepositoryApplicationService } from './repository-application-service';
import {
  REPOSITORY_API_BASE_PATH,
  repositoryRestOperations,
  type ApiPrincipal,
  type RepositoryApiDependencies,
  type RepositoryDto,
} from './repository-api-contracts';
import {
  createRepositoryGraphqlResolvers,
  createRepositoryRestController,
  mapApiError,
  repositoryGraphqlSchema,
} from './repository-api';

const principal: ApiPrincipal = {
  subject: 'user-001',
  tenantId: 'tenant-001',
  roles: ['repository-admin'],
  permissions: [
    'repository:create', 'repository:read', 'repository:update',
    'repository:archive', 'repository:restore', 'repository:delete',
  ],
};

function aggregate() {
  return Repository.create({
    id: 'repo-001', tenantId: 'tenant-001', name: 'master-blueprint',
    displayName: 'MAC Enterprise Master Blueprint', type: 'MASTER_BLUEPRINT',
    owner: { userId: 'user-001', displayName: 'George Juste' },
    now: new Date('2026-08-06T12:00:00.000Z'),
  });
}

function dto(): RepositoryDto {
  return {
    id: 'repo-001', tenantId: 'tenant-001', name: 'master-blueprint',
    displayName: 'MAC Enterprise Master Blueprint', type: 'MASTER_BLUEPRINT',
    status: 'ACTIVE', visibility: 'PRIVATE', classification: 'INTERNAL',
    owner: { userId: 'user-001', displayName: 'George Juste' },
    createdAt: '2026-08-06T12:00:00.000Z', updatedAt: '2026-08-06T12:00:00.000Z',
  };
}

function dependencies(): RepositoryApiDependencies {
  let current = aggregate();
  const commands: RepositoryApplicationService = {
    async create() { current = aggregate(); return current; },
    async update(command) { current.update({ displayName: command.displayName }); return current; },
    async archive() { current.archive(new Date('2026-08-07T12:00:00.000Z')); return current; },
    async restore() { current.restore(new Date('2026-08-08T12:00:00.000Z')); return current; },
    async delete() {},
  };
  return {
    commands,
    queries: {
      async get(_tenantId, id) { return id === 'repo-001' ? dto() : null; },
      async list() { return { items: [dto()] }; },
    },
  };
}

const request = (overrides: Record<string, unknown> = {}) => ({
  principal,
  params: {},
  query: {},
  body: {},
  correlationId: 'corr-001',
  ...overrides,
});

describe('Repository REST controller', () => {
  it('executes the complete REST lifecycle', async () => {
    const controller = createRepositoryRestController(dependencies());
    const created = await controller.create(request({ body: {
      id: 'repo-001', name: 'master-blueprint', displayName: 'MAC Enterprise Master Blueprint',
      type: 'MASTER_BLUEPRINT', owner: { userId: 'user-001', displayName: 'George Juste' },
    } }));
    expect(created.status).toBe(201);
    expect((await controller.get(request({ params: { repositoryId: 'repo-001' } }))).status).toBe(200);
    expect((await controller.list(request())).status).toBe(200);
    expect((await controller.update(request({ params: { repositoryId: 'repo-001' }, body: { displayName: 'Updated' } }))).status).toBe(200);
    expect((await controller.archive(request({ params: { repositoryId: 'repo-001' } }))).status).toBe(200);
    expect((await controller.restore(request({ params: { repositoryId: 'repo-001' } }))).status).toBe(200);
    expect((await controller.delete(request({ params: { repositoryId: 'repo-001' } }))).status).toBe(204);
  });

  it('enforces authentication, authorization, validation, and not-found mapping', async () => {
    const controller = createRepositoryRestController(dependencies());
    expect((await controller.list(request({ principal: undefined }))).status).toBe(401);
    expect((await controller.list(request({ principal: { ...principal, permissions: [] } }))).status).toBe(403);
    const invalid = await controller.create(request({ body: { id: '', name: '', displayName: '', type: 'ENGINEERING', owner: { userId: '', displayName: '' } } }));
    expect(invalid.status).toBe(400);
    expect((invalid.body as { error: { code: string } }).error.code).toBe('VALIDATION_FAILED');
    expect((await controller.get(request({ params: { repositoryId: 'missing' } }))).status).toBe(404);
  });

  it('maps unexpected errors to a versioned correlation-aware envelope', () => {
    const response = mapApiError(new Error('boom'), 'corr-123');
    expect(response).toMatchObject({ status: 500, body: { apiVersion: 'v1', error: { code: 'INTERNAL_ERROR', correlationId: 'corr-123' } } });
  });
});

describe('Repository GraphQL API', () => {
  it('declares required schema operations', () => {
    expect(repositoryGraphqlSchema).toContain('type Query');
    expect(repositoryGraphqlSchema).toContain('createRepository');
    expect(repositoryGraphqlSchema).toContain('archiveRepository');
    expect(repositoryGraphqlSchema).toContain('deleteRepository');
  });

  it('executes queries and mutations with authorization', async () => {
    const resolvers = createRepositoryGraphqlResolvers(dependencies());
    expect(await resolvers.Query.repository(null, { id: 'repo-001' }, { principal })).toMatchObject({ id: 'repo-001' });
    expect((await resolvers.Query.repositories(null, {}, { principal })).items).toHaveLength(1);
    expect(await resolvers.Mutation.createRepository(null, { input: {
      id: 'repo-001', name: 'master-blueprint', displayName: 'MAC Enterprise Master Blueprint',
      type: 'MASTER_BLUEPRINT', owner: { userId: 'user-001', displayName: 'George Juste' },
    } }, { principal })).toMatchObject({ id: 'repo-001' });
    await expect(resolvers.Query.repositories(null, {}, { principal: { ...principal, permissions: [] } })).rejects.toThrow('Permission repository:read is required.');
  });
});

describe('Repository API contracts', () => {
  it('keeps versioned REST routes and permissions stable', () => {
    expect(REPOSITORY_API_BASE_PATH).toBe('/api/v1/repositories');
    expect(repositoryRestOperations.create).toEqual({ method: 'POST', path: '/api/v1/repositories', permission: 'repository:create' });
    expect(repositoryRestOperations.delete.path).toBe('/api/v1/repositories/:repositoryId');
    expect(Object.keys(repositoryRestOperations)).toEqual(['create', 'list', 'get', 'update', 'archive', 'restore', 'delete']);
  });
});
