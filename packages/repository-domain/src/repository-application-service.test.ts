import { describe, expect, it } from 'vitest';
import {
  DefaultRepositoryApplicationService,
  InMemoryDomainEventPublisher,
  RepositoryAlreadyExistsError,
  RepositoryNotFoundError,
} from './repository-application-service';
import type { RepositoryStore, RepositoryUnitOfWork } from './postgres-repository';
import { Repository } from './repository';

class MemoryStore implements RepositoryStore, RepositoryUnitOfWork {
  private readonly data = new Map<string, Repository>();

  async execute<T>(work: (store: RepositoryStore) => Promise<T>): Promise<T> {
    return work(this);
  }

  async save(repository: Repository): Promise<void> {
    this.data.set(`${repository.tenantId}:${repository.id}`, Repository.rehydrate(repository.snapshot));
  }

  async findById(tenantId: string, repositoryId: string): Promise<Repository | null> {
    const repository = this.data.get(`${tenantId}:${repositoryId}`);
    return repository ? Repository.rehydrate(repository.snapshot) : null;
  }

  async listByTenant(tenantId: string): Promise<Repository[]> {
    return [...this.data.values()].filter((repository) => repository.tenantId === tenantId);
  }

  async delete(tenantId: string, repositoryId: string): Promise<boolean> {
    return this.data.delete(`${tenantId}:${repositoryId}`);
  }
}

const command = () => ({
  id: 'repo-001',
  tenantId: 'tenant-001',
  name: 'master-blueprint',
  displayName: 'MAC Enterprise Master Blueprint',
  type: 'MASTER_BLUEPRINT' as const,
  owner: { userId: 'user-001', displayName: 'George Juste' },
  now: new Date('2026-08-06T12:00:00.000Z'),
});

describe('DefaultRepositoryApplicationService', () => {
  it('creates and publishes', async () => {
    const store = new MemoryStore();
    const publisher = new InMemoryDomainEventPublisher();
    const service = new DefaultRepositoryApplicationService(store, publisher);

    await service.create(command());

    expect(await store.findById('tenant-001', 'repo-001')).not.toBeNull();
    expect(publisher.events.map((event) => event.type)).toEqual(['RepositoryCreated']);
  });

  it('rejects duplicates', async () => {
    const store = new MemoryStore();
    const service = new DefaultRepositoryApplicationService(store, new InMemoryDomainEventPublisher());
    await service.create(command());

    await expect(service.create(command())).rejects.toBeInstanceOf(RepositoryAlreadyExistsError);
  });

  it('updates, archives, restores, and deletes', async () => {
    const store = new MemoryStore();
    const publisher = new InMemoryDomainEventPublisher();
    const service = new DefaultRepositoryApplicationService(store, publisher);
    await service.create(command());
    publisher.clear();

    await service.update({ tenantId: 'tenant-001', repositoryId: 'repo-001', displayName: 'Updated Blueprint' });
    await service.archive({ tenantId: 'tenant-001', repositoryId: 'repo-001' });
    await service.restore({ tenantId: 'tenant-001', repositoryId: 'repo-001' });
    await service.delete({ tenantId: 'tenant-001', repositoryId: 'repo-001' });

    expect(await store.findById('tenant-001', 'repo-001')).toBeNull();
    expect(publisher.events.map((event) => event.type)).toEqual([
      'RepositoryUpdated',
      'RepositoryArchived',
      'RepositoryRestored',
      'RepositoryDeleted',
    ]);
  });

  it('throws not found', async () => {
    const service = new DefaultRepositoryApplicationService(new MemoryStore(), new InMemoryDomainEventPublisher());

    await expect(service.delete({ tenantId: 'tenant-001', repositoryId: 'missing' })).rejects.toBeInstanceOf(RepositoryNotFoundError);
  });

  it('does not publish when the unit of work fails', async () => {
    const publisher = new InMemoryDomainEventPublisher();
    const unitOfWork: RepositoryUnitOfWork = {
      async execute<T>(): Promise<T> {
        throw new Error('transaction failed');
      },
    };
    const service = new DefaultRepositoryApplicationService(unitOfWork, publisher);

    await expect(service.create(command())).rejects.toThrow('transaction failed');
    expect(publisher.events).toEqual([]);
  });
});
