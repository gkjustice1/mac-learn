import {
  Repository,
  type RepositoryClassification,
  type RepositoryDomainEvent,
  type RepositoryOwner,
  type RepositoryType,
  type RepositoryVisibility,
} from './repository';
import type { RepositoryStore } from './postgres-repository';

export interface DomainEventPublisher {
  publish(events: readonly RepositoryDomainEvent[]): Promise<void>;
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
    private readonly store: RepositoryStore,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

  public async create(command: CreateRepositoryCommand): Promise<Repository> {
    const existing = await this.store.findById(command.tenantId, command.id);
    if (existing) {
      throw new RepositoryAlreadyExistsError(command.tenantId, command.id);
    }

    const repository = Repository.create(command);
    await this.persistAndPublish(repository);
    return repository;
  }

  public async update(command: UpdateRepositoryCommand): Promise<Repository> {
    const repository = await this.requireRepository(command.tenantId, command.repositoryId);
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
    await this.persistAndPublish(repository);
    return repository;
  }

  public async archive(command: RepositoryIdentityCommand): Promise<Repository> {
    const repository = await this.requireRepository(command.tenantId, command.repositoryId);
    repository.archive(command.now);
    await this.persistAndPublish(repository);
    return repository;
  }

  public async restore(command: RepositoryIdentityCommand): Promise<Repository> {
    const repository = await this.requireRepository(command.tenantId, command.repositoryId);
    repository.restore(command.now);
    await this.persistAndPublish(repository);
    return repository;
  }

  public async delete(command: DeleteRepositoryCommand): Promise<void> {
    const deleted = await this.store.delete(command.tenantId, command.repositoryId);
    if (!deleted) {
      throw new RepositoryNotFoundError(command.tenantId, command.repositoryId);
    }
  }

  private async requireRepository(tenantId: string, repositoryId: string): Promise<Repository> {
    const repository = await this.store.findById(tenantId, repositoryId);
    if (!repository) {
      throw new RepositoryNotFoundError(tenantId, repositoryId);
    }
    return repository;
  }

  private async persistAndPublish(repository: Repository): Promise<void> {
    await this.store.save(repository);
    const events = repository.pullDomainEvents();
    if (events.length > 0) {
      await this.eventPublisher.publish(events);
    }
  }
}
