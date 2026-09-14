# M1 / Vocabulary release gate reconciliation

As of 2026-09-14, evidence baseline main `636d967` (PR #57).
Decision: **BROADER CERTIFICATION OPEN**. This is a reconciliation of available GitHub, production catalog, tests and user-reported browser evidence. It is not a replacement for the complete master PRD/Definition of Done, which was not present in the inspected repository.

## Evidence-backed status

| Gate | Status | Evidence / remaining condition |
|---|---|---|
| Tenant/organization/site foundations | Implemented; full story certification not asserted | Merged PRs #5, #13, #14, #20, #21; organization configuration and tenant-context tests. Overview routes do not by themselves establish every location-management acceptance criterion. |
| Identity, roles, lifecycle and provisioning | Implemented; retirement implementation open | PRs #8–#11, #15–#18, #23–#24, #29–#33; identity, role lifecycle, invitation scope and grants tests. Implement accepted legacy retirement after provisioning checks; helper coverage was expanded by PR #56. Direct invitation RPC coverage is added by PR #55. |
| Tutor workspace and operations | Implemented | PRs #34–#39, #41; tutor data/operations tests. Implement active student assignment access; define separate historical-note retention and complete post-hardening browser checks. |
| Family and Student workspaces | Implemented | PRs #40, #42, #43; family/student tests. Direct invitation RPC SQL gap closed by PR #55: 34 new assertions, 490 total passing on clean replay. |
| Educator workspace and pagination | Original browser blocker cleared | PRs #44 and #52; user confirmed all three Next→Previous controls return to page one and remove page parameters. Academic Lead unauthorized-route and sign-out checks passed per session evidence. Repeat critical paths after PR #53 migration. |
| Historical migration replay / ACL reconciliation | Prior blocker cleared | PRs #46, #48, #49; production `20260909171010`; current clean replay passed. Do not reuse historic object counts as current counts after later migrations. |
| Dependency vulnerability repair | Repair completed | PR #51; Quality includes npm audit. Main application Quality passed after #55. This is the audit result at that commit, not a promise about future advisories. |
| VS-E01-US01 canonical catalog database | Deployed foundation | PR #45 merged; production `20260909143000_add_vocabulary_catalog`; vocabulary_catalog.test.sql. Earlier statements that #45 was unmerged are superseded. |
| VS-E01-US02 multilingual/morphology database | Deployed foundation | PR #50 merged; production `20260910144731_add_vocabulary_multilingual_morphology`; vocabulary_multilingual_morphology.test.sql. Earlier migration blocker is cleared. |
| Vocabulary authoring/review/publishing experience | Not certified | Main contains vocabulary types and database foundation but no Vocabulary authoring page in src/app. Reconcile remaining stories against master specification before representing the Studio as complete. |
| Four-function security correction | Applied and verified | PR #53; production `20260914152633`; exact four bodies/ACLs verified; negative-access smoke checks passed; 456 assertions/22 files passed on clean replay. |
| Leaked-password protection | Resolved | Supabase Pro confirmed; live advisor no longer reports disabled protection after dashboard save. |
| Remaining 38 function warnings | Directions accepted; implementation/evidence pending | [Individual register](../security/security-definer-register.md); no blanket dismissal and no new production privilege changes. |
| Latest deployment alias | Verification incomplete | GitHub Vercel status successful for #57 merge `636d967`; Vercel connection returned access/not-found errors for details. Obtain Production/Current and mac-learn.vercel.app evidence for the current deployment. |
| MAC READS audio | Separate held lane | [Issue #47](https://github.com/gkjustice1/mac-learn/issues/47), draft [PR #31](https://github.com/gkjustice1/mac-learn/pull/31). Server privilege/publishing and real media validation remain required before activation. Does not prevent claiming database-only Vocabulary foundation complete; prevents claiming audio delivery ready. |
| Full M1 / full Vocabulary Studio / full platform | NOT CERTIFIED | Scope reconciliation, security implementation, historical-note retention details and acceptance evidence still required. |

## Immediate closure order

1. Review the 38-function register and map remaining helper/policy dependencies. Student invitation direct RPC test gaps are closed by PR #55 (34 new assertions; 490 total passing). Do not equate a direct name reference with complete regression coverage.
2. Implement accepted legacy retirement and active tutor assignment directions; define historical-note retention separately. Organization-authorized date-only metadata is accepted.
3. Confirm latest production alias and rerun role smoke checks after the hardening migration: authorized workspace, cross-scope denial, invitation authorization, pagination and sign-out.
4. Reconcile every remaining M1 and Vocabulary acceptance criterion against the master specification and capture concrete evidence. No completion percentage is defensible from merged PR count alone.
5. Issue a scoped certification decision only after the required gates pass. M2 roadmap/Skill & Standards Foundation follows M1 certification; audio remains a separately gated lane.

Owner for engineering evidence and tests: engineering. Acceptance/retention decisions: George with the designated security/privacy owner. No new deadlines or risk acceptances are inferred.

## Sources

- [Merged PR #53 and review](https://github.com/gkjustice1/mac-learn/pull/53)
- [Pagination #52](https://github.com/gkjustice1/mac-learn/pull/52), [dependency repair #51](https://github.com/gkjustice1/mac-learn/pull/51)
- [Vocabulary #50](https://github.com/gkjustice1/mac-learn/pull/50), [catalog #45](https://github.com/gkjustice1/mac-learn/pull/45)
- [Reconciliation #48](https://github.com/gkjustice1/mac-learn/pull/48), [manifest](../migrations/migration-reconciliation-manifest.md)
- [Security register](../security/security-definer-register.md); production definitions and migration history inspected read-only, without publishing the raw snapshot.
- Browser evidence: George's screenshots and confirmations in this working session on 2026-09-14; not an automated end-to-end run.

## Helper evidence follow-up

[Boundary map and proposed decisions](../security/helper-coverage-and-decisions.md) maps ten helpers to direct assertions and dependent policy tests. The added 35 assertions passed (525 total across 23 files), followed by clean Quality, Vercel and Codex review. Current aggregate legacy inventory and direct catalog caller review are published with George’s explicit disclosure authorization; the three directions are accepted; provisioning-path retirement work, active tutor assignment implementation and historical-note retention details remain open. Post-merge #56 Application and Database Quality and GitHub Vercel status passed. No blanket security acceptance or broader certification is recorded.

## Accepted policy directions — 2026-09-14

George confirmed legacy retirement after provisioning/regression checks, organization-authorized date-only calendar visibility, and active tutor assignment for current student access. [Decision record and prepared implementation sequence](../security/accepted-policy-directions.md) supersedes earlier pending-direction wording in this checklist and linked proposals. Historical-note retention details remain undecided. Policy confirmation closes the direction decision, not the implementation, deployment or broader certification gates. PR #57 post-merge Quality and GitHub Vercel status passed.
