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
