import {
  Repository,
  type RepositoryClassification,
  type RepositoryDomainEvent,
  type RepositoryOwner,
  type RepositoryType,
  type RepositoryVisibility,
} from './repository';
import type { RepositoryStore, RepositoryUnitOfWork } from './postgres-repository';

export type RepositoryApplicationEvent =
  | RepositoryDomainEvent
  | {
      readonly type: 'RepositoryDeleted';
      readonly repositoryId: string;
      readonly tenantId: string;
      readonly occurredAt: Date;
    };

export interface DomainEventPublisher {
  publish(events: readonly RepositoryApplicationEvent[]): Promise<void>;
}

export class InMemoryDomainEventPublisher implements DomainEventPublisher {
  private readonly published: RepositoryApplicationEvent[] = [];

  public async publish(events: readonly RepositoryApplicationEvent[]): Promise<void> {
    this.published.push(...events.map((event) => ({ ...event, occurredAt: new Date(event.occurredAt) })));
  }

  public get events(): readonly RepositoryApplicationEvent[] {
    return this.published.map((event) => ({ ...event, occurredAt: new Date(event.occurredAt) }));
  }

  public clear(): void {
    this.published.length = 0;
  }
}

export interface CreateRepositoryCommand {
  id: string;
  tenantId: string;
  name: string;
  displayName: string;
  description?: string;
  type: RepositoryType;
  visibility?: RepositoryVisibility;
  classification?: RepositoryClassification;
  owner: RepositoryOwner;
  now?: Date;
}

export interface UpdateRepositoryCommand {
  tenantId: string;
  repositoryId: string;
  name?: string;
  displayName?: string;
  description?: string | null;
  type?: RepositoryType;
  visibility?: RepositoryVisibility;
  classification?: RepositoryClassification;
  owner?: RepositoryOwner;
  now?: Date;
}

export interface RepositoryIdentityCommand {
  tenantId: string;
  repositoryId: string;
  now?: Date;
}

export interface DeleteRepositoryCommand {
  tenantId: string;
  repositoryId: string;
  now?: Date;
}

export interface RepositoryApplicationService {
  create(command: CreateRepositoryCommand): Promise<Repository>;
  update(command: UpdateRepositoryCommand): Promise<Repository>;
  archive(command: RepositoryIdentityCommand): Promise<Repository>;
  restore(command: RepositoryIdentityCommand): Promise<Repository>;
  delete(command: DeleteRepositoryCommand): Promise<void>;
}

export class RepositoryNotFoundError extends Error {
  public constructor(tenantId: string, repositoryId: string) {
    super(`Repository ${repositoryId} was not found for tenant ${tenantId}.`);
    this.name = 'RepositoryNotFoundError';
  }
}

export class RepositoryAlreadyExistsError extends Error {
  public constructor(tenantId: string, repositoryId: string) {
    super(`Repository ${repositoryId} already exists for tenant ${tenantId}.`);
    this.name = 'RepositoryAlreadyExistsError';
  }
}

export class DefaultRepositoryApplicationService implements RepositoryApplicationService {
  public constructor(
    private readonly unitOfWork: RepositoryUnitOfWork,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

  public async create(command: CreateRepositoryCommand): Promise<Repository> {
    const result = await this.unitOfWork.execute(async (store) => {
      const existing = await store.findById(command.tenantId, command.id);
      if (existing) throw new RepositoryAlreadyExistsError(command.tenantId, command.id);

      const repository = Repository.create(command);
      await store.save(repository);
      return { repository, events: repository.pullDomainEvents() };
    });

    await this.publish(result.events);
    return result.repository;
  }

  public async update(command: UpdateRepositoryCommand): Promise<Repository> {
    return this.mutate(command.tenantId, command.repositoryId, async (repository) => {
      repository.update({
        name: command.name,
        displayName: command.displayName,
        description: command.description,
        type: command.type,
        visibility: command.visibility,
        classification: command.classification,
        owner: command.owner,
        now: command.now,
      });
    });
  }

  public async archive(command: RepositoryIdentityCommand): Promise<Repository> {
    return this.mutate(command.tenantId, command.repositoryId, async (repository) => {
      repository.archive(command.now);
    });
  }

  public async restore(command: RepositoryIdentityCommand): Promise<Repository> {
    return this.mutate(command.tenantId, command.repositoryId, async (repository) => {
      repository.restore(command.now);
    });
  }

  public async delete(command: DeleteRepositoryCommand): Promise<void> {
    const event = await this.unitOfWork.execute(async (store) => {
      const deleted = await store.delete(command.tenantId, command.repositoryId);
      if (!deleted) throw new RepositoryNotFoundError(command.tenantId, command.repositoryId);

      return {
        type: 'RepositoryDeleted' as const,
        repositoryId: command.repositoryId,
        tenantId: command.tenantId,
        occurredAt: new Date(command.now ?? new Date()),
      };
    });

    await this.publish([event]);
  }

  private async mutate(
    tenantId: string,
    repositoryId: string,
    mutation: (repository: Repository) => Promise<void>,
  ): Promise<Repository> {
    const result = await this.unitOfWork.execute(async (store) => {
      const repository = await this.requireRepository(store, tenantId, repositoryId);
      await mutation(repository);
      await store.save(repository);
      return { repository, events: repository.pullDomainEvents() };
    });

    await this.publish(result.events);
    return result.repository;
  }

  private async requireRepository(
    store: RepositoryStore,
    tenantId: string,
    repositoryId: string,
  ): Promise<Repository> {
    const repository = await store.findById(tenantId, repositoryId);
    if (!repository) throw new RepositoryNotFoundError(tenantId, repositoryId);
    return repository;
  }

  private async publish(events: readonly RepositoryApplicationEvent[]): Promise<void> {
    if (events.length > 0) await this.eventPublisher.publish(events);
  }
}
