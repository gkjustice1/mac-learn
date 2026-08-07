# MEAF Assessment S1-001.4 — Repository REST/GraphQL API & CI Recovery

You are joining an active MEKOS sprint. The Repository domain, PostgreSQL persistence adapter, and application service already exist. Your assignment is to complete the Repository REST/GraphQL API story and drive it through its Definition of Done.

## Objectives

- Understand the existing architecture before changing it.
- Diagnose failures using build, test, migration, and CI evidence.
- Implement or repair the REST and GraphQL API surface.
- Preserve tenant isolation, validation, authorization hooks, and consistent error mapping.
- Verify PostgreSQL-backed behavior.
- Produce a review-ready pull request with a concise root-cause and Definition of Done summary.

## Required API surface

REST:
- POST /repositories
- GET /repositories/{id}
- GET /repositories
- PATCH /repositories/{id}
- POST /repositories/{id}/archive
- POST /repositories/{id}/restore
- DELETE /repositories/{id}

GraphQL:
- Repository query
- Repository list query
- Create, update, archive, restore, and delete mutations

## Required quality gates

- TypeScript build
- Database migrations
- Domain unit tests
- Application-service unit tests
- Persistence integration tests
- API unit tests
- API contract tests
- PostgreSQL-backed API integration tests
- GitHub Actions workflow

## Constraints

You may use documentation, local tools, Docker, Git, and normal debugging utilities. Do not disable or delete tests, remove assertions, bypass CI, weaken acceptance criteria, or hard-code secrets.

## Submission

Submit a pull request containing:
- Your implementation
- Passing required checks
- A short root-cause summary for each issue you fixed
- Any assumptions or tradeoffs
- A completed Definition of Done statement explaining whether the story is ready for review
