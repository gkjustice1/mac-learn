# Candidate Requirements — S1-001.4

## Story goal
Complete the Repository REST/GraphQL API and recover the delivery pipeline so the story can satisfy Definition of Done.

## Functional requirements
- Create, get, list, update, archive, restore, and delete Repository operations over REST.
- Equivalent GraphQL query/mutation coverage.
- Standard validation and error envelopes.
- Authentication/authorization hooks preserved.
- Tenant-scoped repository access.

## Technical requirements
- TypeScript build must pass.
- PostgreSQL migration runner must complete successfully.
- Existing domain and application-service tests must remain green.
- Add or repair API unit, contract, and PostgreSQL integration tests.
- GitHub Actions must execute the same build/migration/test sequence used locally.

## Engineering expectations
- Diagnose before changing code.
- Prefer the smallest correct fix.
- Do not suppress failures by weakening tests or workflow gates.
- Document root cause and verification evidence in the pull request.

## Submission checklist
- Pull request opened from candidate branch.
- Required checks green.
- Root-cause notes included.
- Assumptions/tradeoffs documented.
- Definition of Done statement included.
