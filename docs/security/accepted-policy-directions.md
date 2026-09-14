# Accepted security policy directions

Decision owner: George. Confirmed in the working session on 2026-09-14: “POLICY DIRECTIONS CONFIRMED”. This supersedes the pending-direction language in the earlier proposal. It accepts the following directions; implementation and verification are separate gates.

| Policy | Accepted direction | Implementation status |
|---|---|---|
| Legacy access | Retire unused compatibility paths after provisioning checks and migration tests. | Not retired. Existing production behavior remains until a separately reviewed migration is applied. |
| Calendar visibility | Accept date-only lookup within an authorized organization, including another site; preserve student/classroom restrictions. | Metadata boundary accepted. Re-review if returned fields or tenant authorization changes. Existing PR #53 implementation and tests supply technical evidence; current browser evidence remains required. |
| Tutor access | Require an active assignment for current student access; handle historical notes separately under a defined retention rule. | Not implemented. No retention period, historical-note access duration, deletion schedule or grace period was selected. |

This is not full platform certification, blanket acceptance of all function warnings, or approval to apply a new production migration. Standing engineering approval permits branch work and routine merges. Production migration authorization remains separate.

## Prepared implementation sequence

1. Review enterprise provisioning paths in `src/app/actions.ts` and `src/app/platform/students/actions.ts`, the protected provisioning function in `20260829211313_grant_invitation_service_role_access.sql`, and Student linking in `20260901090000_invite_existing_student_login.sql`. Test normal success, partial failure, existing Auth identity and disabled enterprise identity before concluding legacy fallback is unnecessary. The zero aggregate inventory alone is insufficient.
2. Prepare an isolated retirement migration removing legacy policies on students, tutor profiles and sessions, removing the Family legacy alternative and the legacy alternative in `mac_can_manage_tutor_profile`, then remove unused eligibility functions after dependency verification. Preserve enterprise access. Replace legacy-success regression expectations with denial expectations and verify normal enterprise provisioning/access on clean replay. Do not rewrite historical migration files.
3. Specify an explicit tutor-to-student assignment lifecycle, with organization/site scope, start/end validity and revocation. An active tutor role is not by itself an active assignment to a particular student. The current helper accepts any matching historical session; changing it needs an assignment model or an explicitly approved scheduling-based contract, not an arbitrary time cutoff.
4. Separate current-student access from historical-session ownership before changing the shared helper. `mac_tutor_owns_session` currently depends on `mac_tutor_is_assigned_to_student`; changing only the latter would also change historical note access. Define historical note read/write permissions and retention before this migration is finalized. No data deletion is implied.
5. Run clean replay, the full database suite, Quality, Vercel and Codex review. Obtain specific production migration authorization, apply only reviewed SQL, then repeat role/browser checks and reconcile certification evidence.

## Evidence baseline

PR #57 merged as `636d967`; its post-merge Application Quality, Database Quality and GitHub Vercel status passed. PR #56 introduced 35 helper assertions, bringing the verified suite to 525 across 23 files. GitHub Vercel status does not independently establish the Production/Current alias.

Remaining product detail: historical-note retention/access rule. Remaining engineering gates: provisioning checks, legacy retirement, active assignment implementation, regression/deployment verification, browser evidence and master M1/Vocabulary acceptance reconciliation. No accepted direction is marked deployed by this document.
