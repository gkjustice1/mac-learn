import type { Pool, PoolClient, QueryResultRow } from 'pg';
import {
  Repository,
  type RepositoryClassification,
  type RepositoryProps,
  type RepositoryStatus,
  type RepositoryType,
  type RepositoryVisibility,
} from './repository';

interface RepositoryRow extends QueryResultRow {
  id: string;
  tenant_id: string;
  name: string;
  display_name: string;
  description: string | null;
  repository_type: RepositoryType;
  status: RepositoryStatus;
  visibility: RepositoryVisibility;
  classification: RepositoryClassification;
  owner_user_id: string;
  owner_display_name: string;
  created_at: Date;
  updated_at: Date;
  archived_at: Date | null;
}

export interface RepositoryStore {
  save(repository: Repository): Promise<void>;
  findById(tenantId: string, repositoryId: string): Promise<Repository | null>;
  listByTenant(tenantId: string): Promise<Repository[]>;
  delete(tenantId: string, repositoryId: string): Promise<boolean>;
}

export interface RepositoryUnitOfWork {
  execute<T>(work: (store: RepositoryStore) => Promise<T>): Promise<T>;
}

type QueryExecutor = Pick<PoolClient, 'query'>;
type TransactionConnector = Partial<Pick<Pool, 'connect'>>;

export function mapRepositoryToParameters(repository: Repository): readonly unknown[] {
  const snapshot = repository.snapshot;
  return [
    snapshot.id,
    snapshot.tenantId,
    snapshot.name,
    snapshot.displayName,
    snapshot.description ?? null,
    snapshot.type,
    snapshot.status,
    snapshot.visibility,
    snapshot.classification,
    snapshot.owner.userId,
    snapshot.owner.displayName,
    snapshot.createdAt,
    snapshot.updatedAt,
    snapshot.archivedAt ?? null,
  ];
}

export function mapRowToRepository(row: RepositoryRow): Repository {
  const props: RepositoryProps = {
    id: row.id,
    tenantId: row.tenant_id,
    name: row.name,
    displayName: row.display_name,
    description: row.description ?? undefined,
    type: row.repository_type,
    status: row.status,
    visibility: row.visibility,
    classification: row.classification,
    owner: {
      userId: row.owner_user_id,
      displayName: row.owner_display_name,
    },
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at),
    archivedAt: row.archived_at ? new Date(row.archived_at) : undefined,
  };

  return Repository.rehydrate(props);
}

export class PostgresRepositoryStore implements RepositoryStore, RepositoryUnitOfWork {
  public constructor(private readonly executor: QueryExecutor & TransactionConnector) {}

  public async save(repository: Repository): Promise<void> {
    await this.executor.query(
      `INSERT INTO repositories (
        id, tenant_id, name, display_name, description, repository_type,
        status, visibility, classification, owner_user_id, owner_display_name,
        created_at, updated_at, archived_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
      )
      ON CONFLICT (tenant_id, id) DO UPDATE SET
        name = EXCLUDED.name,
        display_name = EXCLUDED.display_name,
        description = EXCLUDED.description,
        repository_type = EXCLUDED.repository_type,
        status = EXCLUDED.status,
        visibility = EXCLUDED.visibility,
        classification = EXCLUDED.classification,
        owner_user_id = EXCLUDED.owner_user_id,
        owner_display_name = EXCLUDED.owner_display_name,
        updated_at = EXCLUDED.updated_at,
        archived_at = EXCLUDED.archived_at`,
      [...mapRepositoryToParameters(repository)],
    );
  }

  public async findById(tenantId: string, repositoryId: string): Promise<Repository | null> {
    const result = await this.executor.query<RepositoryRow>(
      `SELECT * FROM repositories WHERE tenant_id = $1 AND id = $2`,
      [tenantId, repositoryId],
    );

    return result.rows[0] ? mapRowToRepository(result.rows[0]) : null;
  }

  public async listByTenant(tenantId: string): Promise<Repository[]> {
    const result = await this.executor.query<RepositoryRow>(
      `SELECT * FROM repositories WHERE tenant_id = $1 ORDER BY created_at, id`,
      [tenantId],
    );

    return result.rows.map(mapRowToRepository);
  }

  public async delete(tenantId: string, repositoryId: string): Promise<boolean> {
    const result = await this.executor.query(
      `DELETE FROM repositories WHERE tenant_id = $1 AND id = $2`,
      [tenantId, repositoryId],
    );

    return (result.rowCount ?? 0) > 0;
  }

  public async execute<T>(work: (store: RepositoryStore) => Promise<T>): Promise<T> {
    if (!this.executor.connect) {
      return work(this);
    }

    const client = await this.executor.connect();
    const transactionalStore = new PostgresRepositoryStore(client);
    try {
      await client.query('BEGIN');
      const result = await work(transactionalStore);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
