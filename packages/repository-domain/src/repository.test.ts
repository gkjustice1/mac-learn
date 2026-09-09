import { describe, expect, it } from 'vitest';
import { Repository, RepositoryDomainError } from './repository';

describe('Repository aggregate', () => {
  const now = new Date('2026-08-06T12:00:00.000Z');

  function createRepository() {
    return Repository.create({
      id: 'repo-001',
      tenantId: 'tenant-001',
      name: 'master-blueprint',
      displayName: 'MAC Enterprise Master Blueprint',
      description: 'Authoritative enterprise knowledge repository',
      type: 'MASTER_BLUEPRINT',
      owner: { userId: 'user-001', displayName: 'George Juste' },
      now,
    });
  }

  it('creates an active repository with normalized values and a creation event', () => {
    const repository = Repository.create({
      id: ' repo-001 ',
      tenantId: ' tenant-001 ',
      name: 'master-blueprint',
      displayName: ' MAC Enterprise Master Blueprint ',
      description: ' Authoritative enterprise knowledge repository ',
      type: 'MASTER_BLUEPRINT',
      owner: { userId: ' user-001 ', displayName: ' George Juste ' },
      now,
    });

    expect(repository.snapshot).toMatchObject({
      id: 'repo-001',
      tenantId: 'tenant-001',
      name: 'master-blueprint',
      displayName: 'MAC Enterprise Master Blueprint',
      description: 'Authoritative enterprise knowledge repository',
      status: 'ACTIVE',
      visibility: 'PRIVATE',
      classification: 'INTERNAL',
      owner: { userId: 'user-001', displayName: 'George Juste' },
    });
    expect(repository.pullDomainEvents()).toEqual([
      {
        type: 'RepositoryCreated',
        repositoryId: 'repo-001',
        tenantId: 'tenant-001',
        occurredAt: now,
      },
    ]);
  });

  it('rejects invalid repository names', () => {
    expect(() =>
      Repository.create({
        id: 'repo-001',
        tenantId: 'tenant-001',
        name: 'Invalid Name',
        displayName: 'Invalid Repository',
        type: 'ENGINEERING',
        owner: { userId: 'user-001', displayName: 'George Juste' },
      }),
    ).toThrow(RepositoryDomainError);
  });

  it('updates repository metadata and emits an update event', () => {
    const repository = createRepository();
    repository.pullDomainEvents();
    const updatedAt = new Date('2026-08-07T12:00:00.000Z');

    repository.update({
      displayName: 'MAC Enterprise Blueprint',
      visibility: 'ENTERPRISE',
      classification: 'CONFIDENTIAL',
      now: updatedAt,
    });

    expect(repository.snapshot).toMatchObject({
      displayName: 'MAC Enterprise Blueprint',
      visibility: 'ENTERPRISE',
      classification: 'CONFIDENTIAL',
      updatedAt,
    });
    expect(repository.pullDomainEvents()).toEqual([
      {
        type: 'RepositoryUpdated',
        repositoryId: 'repo-001',
        tenantId: 'tenant-001',
        occurredAt: updatedAt,
      },
    ]);
  });

  it('archives and restores a repository with lifecycle events', () => {
    const repository = createRepository();
    repository.pullDomainEvents();
    const archivedAt = new Date('2026-08-08T12:00:00.000Z');
    const restoredAt = new Date('2026-08-09T12:00:00.000Z');

    repository.archive(archivedAt);
    expect(repository.snapshot.status).toBe('ARCHIVED');
    expect(repository.snapshot.archivedAt).toEqual(archivedAt);

    repository.restore(restoredAt);
    expect(repository.snapshot.status).toBe('ACTIVE');
    expect(repository.snapshot.archivedAt).toBeUndefined();
    expect(repository.pullDomainEvents()).toEqual([
      {
        type: 'RepositoryArchived',
        repositoryId: 'repo-001',
        tenantId: 'tenant-001',
        occurredAt: archivedAt,
      },
      {
        type: 'RepositoryRestored',
        repositoryId: 'repo-001',
        tenantId: 'tenant-001',
        occurredAt: restoredAt,
      },
    ]);
  });

  it('prevents modification while archived', () => {
    const repository = createRepository();
    repository.archive();

    expect(() => repository.update({ displayName: 'Blocked Update' })).toThrow(
      'Archived repositories cannot be modified.',
    );
  });

  it('rejects inconsistent rehydrated lifecycle state', () => {
    expect(() =>
      Repository.rehydrate({
        ...createRepository().snapshot,
        status: 'ARCHIVED',
        archivedAt: undefined,
      }),
    ).toThrow('Archived repositories require archivedAt.');
  });

  it('clears domain events after they are pulled', () => {
    const repository = createRepository();
    expect(repository.pullDomainEvents()).toHaveLength(1);
    expect(repository.pullDomainEvents()).toEqual([]);
  });
});
