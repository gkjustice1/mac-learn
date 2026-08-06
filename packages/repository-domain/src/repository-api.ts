import {
  REPOSITORY_API_VERSION,
  type ApiErrorCode,
  type ApiErrorResponse,
  type ApiPrincipal,
  type CreateRepositoryRequest,
  type ListRepositoriesQuery,
  type RepositoryApiDependencies,
  type RepositoryDto,
  type RepositoryPermission,
  type UpdateRepositoryRequest,
  toCreateRepositoryCommand,
  toDeleteRepositoryCommand,
  toRepositoryIdentityCommand,
  toUpdateRepositoryCommand,
} from './repository-api-contracts';
import {
  RepositoryAlreadyExistsError,
  RepositoryNotFoundError,
} from './repository-application-service';
import type { Repository } from './repository';

export interface ApiRequest<TBody = unknown, TQuery = Record<string, unknown>> {
  principal?: ApiPrincipal;
  params: { repositoryId?: string };
  query: TQuery;
  body: TBody;
  correlationId: string;
}

export interface ApiResponse<T = unknown> {
  status: number;
  body?: T;
}

export class ApiValidationError extends Error {
  public constructor(public readonly details: { field: string; message: string }[]) {
    super('Request validation failed.');
    this.name = 'ApiValidationError';
  }
}

export class ApiAuthenticationError extends Error {
  public constructor() {
    super('Authentication is required.');
    this.name = 'ApiAuthenticationError';
  }
}

export class ApiAuthorizationError extends Error {
  public constructor(permission: RepositoryPermission) {
    super(`Permission ${permission} is required.`);
    this.name = 'ApiAuthorizationError';
  }
}

function requirePrincipal(request: ApiRequest): ApiPrincipal {
  if (!request.principal) throw new ApiAuthenticationError();
  return request.principal;
}

function authorize(principal: ApiPrincipal, permission: RepositoryPermission): void {
  if (!principal.permissions.includes(permission)) throw new ApiAuthorizationError(permission);
}

function requireRepositoryId(request: ApiRequest): string {
  const repositoryId = request.params.repositoryId?.trim();
  if (!repositoryId) throw new ApiValidationError([{ field: 'repositoryId', message: 'Repository ID is required.' }]);
  return repositoryId;
}

function validateCreate(request: CreateRepositoryRequest): void {
  const details: { field: string; message: string }[] = [];
  if (!request.id?.trim()) details.push({ field: 'id', message: 'ID is required.' });
  if (!request.name?.trim()) details.push({ field: 'name', message: 'Name is required.' });
  if (!request.displayName?.trim()) details.push({ field: 'displayName', message: 'Display name is required.' });
  if (!request.owner?.userId?.trim()) details.push({ field: 'owner.userId', message: 'Owner user ID is required.' });
  if (!request.owner?.displayName?.trim()) details.push({ field: 'owner.displayName', message: 'Owner display name is required.' });
  if (details.length) throw new ApiValidationError(details);
}

function toDto(repository: Repository): RepositoryDto {
  const snapshot = repository.snapshot;
  return {
    ...snapshot,
    createdAt: snapshot.createdAt.toISOString(),
    updatedAt: snapshot.updatedAt.toISOString(),
    archivedAt: snapshot.archivedAt?.toISOString(),
  };
}

function errorCode(error: unknown): ApiErrorCode {
  if (error instanceof ApiAuthenticationError) return 'AUTHENTICATION_REQUIRED';
  if (error instanceof ApiAuthorizationError) return 'FORBIDDEN';
  if (error instanceof ApiValidationError) return 'VALIDATION_FAILED';
  if (error instanceof RepositoryNotFoundError) return 'REPOSITORY_NOT_FOUND';
  if (error instanceof RepositoryAlreadyExistsError) return 'REPOSITORY_ALREADY_EXISTS';
  return 'INTERNAL_ERROR';
}

export function mapApiError(error: unknown, correlationId: string): ApiResponse<ApiErrorResponse> {
  const code = errorCode(error);
  const status = code === 'AUTHENTICATION_REQUIRED' ? 401
    : code === 'FORBIDDEN' ? 403
    : code === 'REPOSITORY_NOT_FOUND' ? 404
    : code === 'REPOSITORY_ALREADY_EXISTS' ? 409
    : code === 'VALIDATION_FAILED' ? 400
    : 500;
  return {
    status,
    body: {
      apiVersion: REPOSITORY_API_VERSION,
      error: {
        code,
        message: error instanceof Error ? error.message : 'Unexpected error.',
        correlationId,
        details: error instanceof ApiValidationError ? error.details : undefined,
      },
    },
  };
}

export function createRepositoryRestController(dependencies: RepositoryApiDependencies) {
  async function execute<T>(request: ApiRequest, work: () => Promise<ApiResponse<T>>): Promise<ApiResponse<T | ApiErrorResponse>> {
    try {
      return await work();
    } catch (error) {
      return mapApiError(error, request.correlationId);
    }
  }

  return {
    create(request: ApiRequest<CreateRepositoryRequest>): Promise<ApiResponse<RepositoryDto | ApiErrorResponse>> {
      return execute(request, async () => {
        const principal = requirePrincipal(request);
        authorize(principal, 'repository:create');
        validateCreate(request.body);
        const repository = await dependencies.commands.create(toCreateRepositoryCommand(principal, request.body));
        return { status: 201, body: toDto(repository) };
      });
    },
    get(request: ApiRequest): Promise<ApiResponse<RepositoryDto | ApiErrorResponse>> {
      return execute(request, async () => {
        const principal = requirePrincipal(request);
        authorize(principal, 'repository:read');
        const repository = await dependencies.queries.get(principal.tenantId, requireRepositoryId(request));
        if (!repository) throw new RepositoryNotFoundError(principal.tenantId, requireRepositoryId(request));
        return { status: 200, body: repository };
      });
    },
    list(request: ApiRequest<unknown, ListRepositoriesQuery>) {
      return execute(request, async () => {
        const principal = requirePrincipal(request);
        authorize(principal, 'repository:read');
        return { status: 200, body: await dependencies.queries.list(principal.tenantId, request.query) };
      });
    },
    update(request: ApiRequest<UpdateRepositoryRequest>) {
      return execute(request, async () => {
        const principal = requirePrincipal(request);
        authorize(principal, 'repository:update');
        const repository = await dependencies.commands.update(
          toUpdateRepositoryCommand(principal, requireRepositoryId(request), request.body),
        );
        return { status: 200, body: toDto(repository) };
      });
    },
    archive(request: ApiRequest) {
      return execute(request, async () => {
        const principal = requirePrincipal(request);
        authorize(principal, 'repository:archive');
        const repository = await dependencies.commands.archive(
          toRepositoryIdentityCommand(principal, requireRepositoryId(request)),
        );
        return { status: 200, body: toDto(repository) };
      });
    },
    restore(request: ApiRequest) {
      return execute(request, async () => {
        const principal = requirePrincipal(request);
        authorize(principal, 'repository:restore');
        const repository = await dependencies.commands.restore(
          toRepositoryIdentityCommand(principal, requireRepositoryId(request)),
        );
        return { status: 200, body: toDto(repository) };
      });
    },
    delete(request: ApiRequest) {
      return execute(request, async () => {
        const principal = requirePrincipal(request);
        authorize(principal, 'repository:delete');
        await dependencies.commands.delete(toDeleteRepositoryCommand(principal, requireRepositoryId(request)));
        return { status: 204 };
      });
    },
  };
}

export const repositoryGraphqlSchema = `
  enum RepositoryType { MASTER_BLUEPRINT ENGINEERING CURRICULUM AI RESEARCH GOVERNANCE OPERATIONS COMMERCIAL }
  enum RepositoryStatus { ACTIVE ARCHIVED }
  enum RepositoryVisibility { PRIVATE TENANT ENTERPRISE }
  enum RepositoryClassification { PUBLIC INTERNAL CONFIDENTIAL RESTRICTED }

  type RepositoryOwner { userId: ID!, displayName: String! }
  type Repository {
    id: ID!
    tenantId: ID!
    name: String!
    displayName: String!
    description: String
    type: RepositoryType!
    status: RepositoryStatus!
    visibility: RepositoryVisibility!
    classification: RepositoryClassification!
    owner: RepositoryOwner!
    createdAt: String!
    updatedAt: String!
    archivedAt: String
  }
  type RepositoryConnection { items: [Repository!]!, nextCursor: String }
  input RepositoryOwnerInput { userId: ID!, displayName: String! }
  input CreateRepositoryInput { id: ID!, name: String!, displayName: String!, description: String, type: RepositoryType!, visibility: RepositoryVisibility, classification: RepositoryClassification, owner: RepositoryOwnerInput! }
  input UpdateRepositoryInput { name: String, displayName: String, description: String, type: RepositoryType, visibility: RepositoryVisibility, classification: RepositoryClassification, owner: RepositoryOwnerInput }
  type Query { repository(id: ID!): Repository, repositories(status: RepositoryStatus, type: RepositoryType, visibility: RepositoryVisibility, limit: Int, cursor: String): RepositoryConnection! }
  type Mutation { createRepository(input: CreateRepositoryInput!): Repository!, updateRepository(id: ID!, input: UpdateRepositoryInput!): Repository!, archiveRepository(id: ID!): Repository!, restoreRepository(id: ID!): Repository!, deleteRepository(id: ID!): Boolean! }
`;

export function createRepositoryGraphqlResolvers(dependencies: RepositoryApiDependencies) {
  const principal = (context: { principal?: ApiPrincipal }) => {
    if (!context.principal) throw new ApiAuthenticationError();
    return context.principal;
  };
  return {
    Query: {
      repository: async (_: unknown, args: { id: string }, context: { principal?: ApiPrincipal }) => {
        const actor = principal(context); authorize(actor, 'repository:read');
        return dependencies.queries.get(actor.tenantId, args.id);
      },
      repositories: async (_: unknown, args: ListRepositoriesQuery, context: { principal?: ApiPrincipal }) => {
        const actor = principal(context); authorize(actor, 'repository:read');
        return dependencies.queries.list(actor.tenantId, args);
      },
    },
    Mutation: {
      createRepository: async (_: unknown, args: { input: CreateRepositoryRequest }, context: { principal?: ApiPrincipal }) => {
        const actor = principal(context); authorize(actor, 'repository:create'); validateCreate(args.input);
        return toDto(await dependencies.commands.create(toCreateRepositoryCommand(actor, args.input)));
      },
      updateRepository: async (_: unknown, args: { id: string; input: UpdateRepositoryRequest }, context: { principal?: ApiPrincipal }) => {
        const actor = principal(context); authorize(actor, 'repository:update');
        return toDto(await dependencies.commands.update(toUpdateRepositoryCommand(actor, args.id, args.input)));
      },
      archiveRepository: async (_: unknown, args: { id: string }, context: { principal?: ApiPrincipal }) => {
        const actor = principal(context); authorize(actor, 'repository:archive');
        return toDto(await dependencies.commands.archive(toRepositoryIdentityCommand(actor, args.id)));
      },
      restoreRepository: async (_: unknown, args: { id: string }, context: { principal?: ApiPrincipal }) => {
        const actor = principal(context); authorize(actor, 'repository:restore');
        return toDto(await dependencies.commands.restore(toRepositoryIdentityCommand(actor, args.id)));
      },
      deleteRepository: async (_: unknown, args: { id: string }, context: { principal?: ApiPrincipal }) => {
        const actor = principal(context); authorize(actor, 'repository:delete');
        await dependencies.commands.delete(toDeleteRepositoryCommand(actor, args.id));
        return true;
      },
    },
  };
}
