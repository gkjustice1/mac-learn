import {
  RepositoryDisplayName,
  RepositoryId,
  RepositoryName,
  RepositoryOwnerId,
  TenantId,
} from './value-objects';

export type RepositoryType =
  | 'MASTER_BLUEPRINT'
  | 'ENGINEERING'
  | 'CURRICULUM'
  | 'AI'
  | 'RESEARCH'
  | 'GOVERNANCE'
  | 'OPERATIONS'
  | 'COMMERCIAL';

export type RepositoryStatus = 'ACTIVE' | 'ARCHIVED';
export type RepositoryVisibility = 'PRIVATE' | 'TENANT' | 'ENTERPRISE';
export type RepositoryClassification =
  | 'PUBLIC'
  | 'INTERNAL'
  | 'CONFIDENTIAL'
  | 'RESTRICTED';

export interface RepositoryOwner {
  readonly userId: string;
  readonly displayName: string;
}

export interface RepositoryProps {
  readonly id: string;
  readonly tenantId: string;
  name: string;
  displayName: string;
  description?: string;
  type: RepositoryType;
  status: RepositoryStatus;
  visibility: RepositoryVisibility;
  classification: RepositoryClassification;
  owner: RepositoryOwner;
  readonly createdAt: Date;
  updatedAt: Date;
  archivedAt?: Date;
}

export type RepositoryDomainEvent =
  | {
      readonly type: 'RepositoryCreated';
      readonly repositoryId: string;
      readonly tenantId: string;
      readonly occurredAt: Date;
    }
  | {
      readonly type: 'RepositoryUpdated';
      readonly repositoryId: string;
      readonly tenantId: string;
      readonly occurredAt: Date;
    }
  | {
      readonly type: 'RepositoryArchived';
      readonly repositoryId: string;
      readonly tenantId: string;
      readonly occurredAt: Date;
    }
  | {
      readonly type: 'RepositoryRestored';
      readonly repositoryId: string;
      readonly tenantId: string;
      readonly occurredAt: Date;
    };

export class RepositoryDomainError extends Error {
  public constructor(message: string) {
    super(message);
    this.name = 'RepositoryDomainError';
  }
}

export class Repository {
  private readonly events: RepositoryDomainEvent[] = [];

  private constructor(private readonly props: RepositoryProps) {}

  public static create(input: {
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
  }): Repository {
    const now = input.now ?? new Date();
    const id = RepositoryId.create(input.id);
    const tenantId = TenantId.create(input.tenantId);
    const name = RepositoryName.create(input.name);
    const displayName = RepositoryDisplayName.create(input.displayName);
    const ownerId = RepositoryOwnerId.create(input.owner.userId);
    const ownerDisplayName = Repository.requireText(input.owner.displayName, 'Owner display name');

    const repository = new Repository({
      id: id.value,
      tenantId: tenantId.value,
      name: name.value,
      displayName: displayName.value,
      description: Repository.normalizeDescription(input.description),
      type: input.type,
      status: 'ACTIVE',
      visibility: input.visibility ?? 'PRIVATE',
      classification: input.classification ?? 'INTERNAL',
      owner: { userId: ownerId.value, displayName: ownerDisplayName },
      createdAt: new Date(now),
      updatedAt: new Date(now),
    });

    repository.events.push({
      type: 'RepositoryCreated',
      repositoryId: repository.id,
      tenantId: repository.tenantId,
      occurredAt: new Date(now),
    });

    return repository;
  }

  public static rehydrate(props: RepositoryProps): Repository {
    RepositoryId.create(props.id);
    TenantId.create(props.tenantId);
    RepositoryName.create(props.name);
    RepositoryDisplayName.create(props.displayName);
    RepositoryOwnerId.create(props.owner.userId);
    Repository.requireText(props.owner.displayName, 'Owner display name');

    if (props.status === 'ARCHIVED' && !props.archivedAt) {
      throw new RepositoryDomainError('Archived repositories require archivedAt.');
    }
    if (props.status === 'ACTIVE' && props.archivedAt) {
      throw new RepositoryDomainError('Active repositories cannot have archivedAt.');
    }

    return new Repository({
      ...props,
      owner: { ...props.owner },
      description: Repository.normalizeDescription(props.description),
      createdAt: new Date(props.createdAt),
      updatedAt: new Date(props.updatedAt),
      archivedAt: props.archivedAt ? new Date(props.archivedAt) : undefined,
    });
  }

  public get id(): string {
    return this.props.id;
  }

  public get tenantId(): string {
    return this.props.tenantId;
  }

  public get status(): RepositoryStatus {
    return this.props.status;
  }

  public get snapshot(): Readonly<RepositoryProps> {
    return Object.freeze({
      ...this.props,
      owner: Object.freeze({ ...this.props.owner }),
      createdAt: new Date(this.props.createdAt),
      updatedAt: new Date(this.props.updatedAt),
      archivedAt: this.props.archivedAt ? new Date(this.props.archivedAt) : undefined,
    });
  }

  public update(input: {
    name?: string;
    displayName?: string;
    description?: string | null;
    type?: RepositoryType;
    visibility?: RepositoryVisibility;
    classification?: RepositoryClassification;
    owner?: RepositoryOwner;
    now?: Date;
  }): void {
    this.assertActive();

    if (input.name !== undefined) this.props.name = RepositoryName.create(input.name).value;
    if (input.displayName !== undefined) {
      this.props.displayName = RepositoryDisplayName.create(input.displayName).value;
    }
    if (input.description !== undefined) {
      this.props.description = Repository.normalizeDescription(input.description ?? undefined);
    }
    if (input.type !== undefined) this.props.type = input.type;
    if (input.visibility !== undefined) this.props.visibility = input.visibility;
    if (input.classification !== undefined) this.props.classification = input.classification;
    if (input.owner !== undefined) {
      this.props.owner = {
        userId: RepositoryOwnerId.create(input.owner.userId).value,
        displayName: Repository.requireText(input.owner.displayName, 'Owner display name'),
      };
    }

    const now = input.now ?? new Date();
    this.props.updatedAt = new Date(now);
    this.events.push({
      type: 'RepositoryUpdated',
      repositoryId: this.id,
      tenantId: this.tenantId,
      occurredAt: new Date(now),
    });
  }

  public archive(now: Date = new Date()): void {
    if (this.props.status === 'ARCHIVED') {
      throw new RepositoryDomainError('Repository is already archived.');
    }
    this.props.status = 'ARCHIVED';
    this.props.archivedAt = new Date(now);
    this.props.updatedAt = new Date(now);
    this.events.push({
      type: 'RepositoryArchived',
      repositoryId: this.id,
      tenantId: this.tenantId,
      occurredAt: new Date(now),
    });
  }

  public restore(now: Date = new Date()): void {
    if (this.props.status !== 'ARCHIVED') {
      throw new RepositoryDomainError('Only archived repositories can be restored.');
    }
    this.props.status = 'ACTIVE';
    this.props.archivedAt = undefined;
    this.props.updatedAt = new Date(now);
    this.events.push({
      type: 'RepositoryRestored',
      repositoryId: this.id,
      tenantId: this.tenantId,
      occurredAt: new Date(now),
    });
  }

  public pullDomainEvents(): readonly RepositoryDomainEvent[] {
    const pending = this.events.map((event) => ({ ...event, occurredAt: new Date(event.occurredAt) }));
    this.events.length = 0;
    return pending;
  }

  private assertActive(): void {
    if (this.props.status !== 'ACTIVE') {
      throw new RepositoryDomainError('Archived repositories cannot be modified.');
    }
  }

  private static requireText(value: string, label: string): string {
    const normalized = value.trim();
    if (!normalized) throw new RepositoryDomainError(`${label} is required.`);
    return normalized;
  }

  private static normalizeDescription(value?: string): string | undefined {
    const normalized = value?.trim();
    if (!normalized) return undefined;
    if (normalized.length > 2000) {
      throw new RepositoryDomainError('Repository description cannot exceed 2000 characters.');
    }
    return normalized;
  }
}
