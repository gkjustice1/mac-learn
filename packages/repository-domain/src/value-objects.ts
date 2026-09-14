import { RepositoryDomainError } from './repository';

abstract class StringValueObject {
  protected constructor(public readonly value: string) {}

  public equals(other: StringValueObject): boolean {
    return this.constructor === other.constructor && this.value === other.value;
  }

  public toString(): string {
    return this.value;
  }
}

function requireValue(value: string, label: string): string {
  const normalized = value.trim();
  if (!normalized) throw new RepositoryDomainError(`${label} is required.`);
  return normalized;
}

export class RepositoryId extends StringValueObject {
  private constructor(value: string) { super(value); }
  public static create(value: string): RepositoryId {
    return new RepositoryId(requireValue(value, 'Repository id'));
  }
}

export class TenantId extends StringValueObject {
  private constructor(value: string) { super(value); }
  public static create(value: string): TenantId {
    return new TenantId(requireValue(value, 'Tenant id'));
  }
}

export class RepositoryName extends StringValueObject {
  private constructor(value: string) { super(value); }
  public static create(value: string): RepositoryName {
    const normalized = requireValue(value, 'Repository name');
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(normalized)) {
      throw new RepositoryDomainError('Repository name must use lowercase letters, numbers, and single hyphens.');
    }
    if (normalized.length > 100) throw new RepositoryDomainError('Repository name cannot exceed 100 characters.');
    return new RepositoryName(normalized);
  }
}

export class RepositoryDisplayName extends StringValueObject {
  private constructor(value: string) { super(value); }
  public static create(value: string): RepositoryDisplayName {
    const normalized = requireValue(value, 'Repository display name');
    if (normalized.length < 3 || normalized.length > 160) {
      throw new RepositoryDomainError('Repository display name must be between 3 and 160 characters.');
    }
    return new RepositoryDisplayName(normalized);
  }
}

export class RepositoryOwnerId extends StringValueObject {
  private constructor(value: string) { super(value); }
  public static create(value: string): RepositoryOwnerId {
    return new RepositoryOwnerId(requireValue(value, 'Owner user id'));
  }
}
