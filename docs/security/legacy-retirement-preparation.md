# Legacy access retirement preparation

Approved policy direction: retire unused compatibility paths after provisioning checks and migration tests. Production application is not authorized by this branch.

## Change scope

Migration `20260914205908_retire_legacy_access_paths.sql` refuses execution if any profile lacks a corresponding enterprise user. It removes legacy administrator policies on students, tutor profiles and sessions; removes the Family student SELECT legacy-parent alternative; removes the legacy alternative from `mac_can_manage_tutor_profile`; and drops the two now-unused eligibility helpers without CASCADE. Enterprise authorization alternatives and canonical Family relationships remain. Historical migration files are unchanged.

This retirement targets those reviewed paths. It does not delete profiles, students, sessions or notes, does not remove the separate `current_user_role` function, and does not implement tutor-assignment or historical-note retention changes. Other uses of the legacy profile role are outside this migration and must not be described as universally retired.

## Provisioning review and regression scope

The server invitation paths in `src/app/actions.ts` and `src/app/platform/students/actions.ts` call guarded creation/linking RPCs. General identity provisioning creates people, users and profiles in one database function. Its SQL transaction rolls back if the final profile insert fails. Role assignment happens afterward; the server failure path invokes protected cleanup and deletes the Auth identity only after cleanup reports cleaned or missing. Student linking uses the canonical Student invitation RPC already covered by PR #55.

Extended `invitation_service_role_grants.test.sql` verifies mismatched/missing Auth identity rejection, failed final site validation leaving no person/user/profile, duplicate disabled-identity rejection, cleanup refusing disabled users and preservation of a single linked profile. Existing tests retain successful creation, role/audit linkage, active-user preservation and cleanup after provisioning. These are SQL regression tests; email delivery, Auth API failure and server-side cleanup orchestration still need integration/browser evidence. No real invitation emails are sent by this suite.

Family and Tutor tests now deny legacy-only identities while preserving canonical guardian and enterprise administrator access. Student enrollment tests verify denied legacy updates affect zero rows and create no audit event. Helper removal is asserted directly. The existing tests of tutor historical-session behavior remain unchanged pending its separate policy implementation.

## Gates

Run clean replay, the complete database suite, Application Quality, Vercel and Codex on this branch; resolve findings. Before production application, rerun the aggregate legacy inventory, verify no external caller needs the retired helpers, and obtain specific authorization for this migration. Full certification remains open for retirement deployment, invitation integration evidence, tutor assignment/retention work, production alias/browser evidence and master acceptance reconciliation.

## September 15 verification update

Read-only production inventory at 2026-09-15 12:23 UTC: zero profiles without enterprise users; one profile labelled admin, but zero eligible legacy administrators (the labelled profile has an enterprise identity); zero legacy parent/student links. The four policy dependencies remain the expected students administrator, tutor_profiles administrator, sessions administrator and Family student SELECT policies. The only function-body caller is `public.mac_can_manage_tutor_profile`. No view/materialized-view references were found; pg_cron is not installed.

Application/runtime source search found no retiring-helper calls. The deployed `mac-reads-audio-bootstrap` Edge Function (version 5) contains no references. The accessible owner-scoped GitHub code search returned no matches; this is not proof about private/unindexed repositories, off-platform clients, dynamic calls or previously issued API requests. External-consumer verification remains bounded by those visibility limits.

`tests/invitation-orchestration.test.mjs` executes the real invitation server action with mocked framework/Auth/Data API boundaries. Eleven tests cover successful ordered provisioning, normalized email/callback destination, tenant/authorization rejection before invitation, Auth failure, identity and role-assignment failures, cleanup-before-Auth-deletion, preservation when cleanup reports not_invited, and preservation on cleanup error. All 93 application tests pass locally. These complement the 536 database assertions; they are not a live Auth/email/browser integration test. No invitation was sent and no production identity was created during this verification.

Remaining pre-retirement evidence: use an isolated non-production Auth/database deployment and controlled mailbox to exercise invitation delivery, acceptance/password setup, role routing and failure recovery end-to-end. Confirm the external-consumer inventory with its owner or explicitly document acceptance of the visibility limit. Refresh the inventory again immediately before specifically authorized production application. Historical-note access and retention remain undefined and separate from current-student assignment enforcement.
