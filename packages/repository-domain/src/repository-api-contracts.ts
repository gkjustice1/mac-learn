import type {
  RepositoryClassification,
  RepositoryStatus,
  RepositoryType,
  RepositoryVisibility,
} from './repository';
import type {
  CreateRepositoryCommand,
  DeleteRepositoryCommand,
  RepositoryApplicationService,
  RepositoryIdentityCommand,
  UpdateRepositoryCommand,
} from './repository-application-service';

export const REPOSITORY_API_VERSION = 'v1' as const;
export const REPOSITORY_API_BASE_PATH = `/api/${REPOSITORY_API_VERSION}/repositories` as const;

export interface ApiPrincipal {
  subject: string;
  tenantId: string;
  roles: readonly string[];
  permissions: readonly string[];
}

export type RepositoryPermission =
  | 'repository:create'
  | 'repository:read'
  | 'repository:update'
  | 'repository:archive'
  | 'repository:restore'
  | 'repository:delete';

export interface RepositoryDto {
  id: string;
  tenantId: string;
  name: string;
  displayName: string;
  description?: string;
  type: RepositoryType;
  status: RepositoryStatus;
  visibility: RepositoryVisibility;
  classification: RepositoryClassification;
  owner: {
    userId: string;
    displayName: string;
  };
  createdAt: string;
  updatedAt: string;
  archivedAt?: string;
}

export interface CreateRepositoryRequest {
  id: string;
  name: string;
  displayName: string;
  description?: string;
  type: RepositoryType;
  visibility?: RepositoryVisibility;
  classification?: RepositoryClassification;
  owner: {
    userId: string;
    displayName: string;
  };
}

export interface UpdateRepositoryRequest {
  name?: string;
  displayName?: string;
  description?: string | null;
  type?: RepositoryType;
  visibility?: RepositoryVisibility;
  classification?: RepositoryClassification;
  owner?: {
    userId: string;
    displayName: string;
  };
}

export interface RepositoryPathParameters {
  repositoryId: string;
}

export interface ListRepositoriesQuery {
  status?: RepositoryStatus;
  type?: RepositoryType;
  visibility?: RepositoryVisibility;
  limit?: number;
  cursor?: string;
}

export interface ListRepositoriesResponse {
  items: RepositoryDto[];
  nextCursor?: string;
}

export type ApiErrorCode =
  | 'AUTHENTICATION_REQUIRED'
  | 'FORBIDDEN'
  | 'VALIDATION_FAILED'
  | 'REPOSITORY_NOT_FOUND'
  | 'REPOSITORY_ALREADY_EXISTS'
  | 'CONFLICT'
  | 'INTERNAL_ERROR';

export interface ApiErrorDetail {
  field?: string;
  message: string;
}

export interface ApiErrorResponse {
  apiVersion: typeof REPOSITORY_API_VERSION;
  error: {
    code: ApiErrorCode;
    message: string;
    correlationId: string;
    details?: ApiErrorDetail[];
  };
}

export interface RepositoryQueryService {
  get(tenantId: string, repositoryId: string): Promise<RepositoryDto | null>;
  list(tenantId: string, query: ListRepositoriesQuery): Promise<ListRepositoriesResponse>;
}

export interface RepositoryApiDependencies {
  commands: RepositoryApplicationService;
  queries: RepositoryQueryService;
}

export function toCreateRepositoryCommand(
  principal: ApiPrincipal,
  request: CreateRepositoryRequest,
): CreateRepositoryCommand {
  return {
    ...request,
    tenantId: principal.tenantId,
  };
}

export function toUpdateRepositoryCommand(
  principal: ApiPrincipal,
  repositoryId: string,
  request: UpdateRepositoryRequest,
): UpdateRepositoryCommand {
  return {
    ...request,
    tenantId: principal.tenantId,
    repositoryId,
  };
}

export function toRepositoryIdentityCommand(
  principal: ApiPrincipal,
  repositoryId: string,
): RepositoryIdentityCommand {
  return {
    tenantId: principal.tenantId,
    repositoryId,
  };
}

export function toDeleteRepositoryCommand(
  principal: ApiPrincipal,
  repositoryId: string,
): DeleteRepositoryCommand {
  return {
    tenantId: principal.tenantId,
    repositoryId,
  };
}

export const repositoryRestOperations = {
  create: { method: 'POST', path: REPOSITORY_API_BASE_PATH, permission: 'repository:create' },
  list: { method: 'GET', path: REPOSITORY_API_BASE_PATH, permission: 'repository:read' },
  get: { method: 'GET', path: `${REPOSITORY_API_BASE_PATH}/:repositoryId`, permission: 'repository:read' },
  update: { method: 'PATCH', path: `${REPOSITORY_API_BASE_PATH}/:repositoryId`, permission: 'repository:update' },
  archive: { method: 'POST', path: `${REPOSITORY_API_BASE_PATH}/:repositoryId/archive`, permission: 'repository:archive' },
  restore: { method: 'POST', path: `${REPOSITORY_API_BASE_PATH}/:repositoryId/restore`, permission: 'repository:restore' },
  delete: { method: 'DELETE', path: `${REPOSITORY_API_BASE_PATH}/:repositoryId`, permission: 'repository:delete' },
} as const satisfies Record<string, { method: string; path: string; permission: RepositoryPermission }>;
