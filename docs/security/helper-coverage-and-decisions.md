# Helper coverage and security decisions

Baseline: main `77fe9bf` (PR #55), 2026-09-14. Its post-merge Application Quality, Database Quality and GitHub Vercel status all passed. The GitHub status does not independently prove the Production/Current alias.

## Coverage traceability

The following ten helpers previously lacked direct pgTAP references. The four existing transactional suites now add 34 assertions (524 expected total). CI must pass before this new evidence is accepted. Fixtures roll back; no production migration is required. These assertions establish the listed boundaries, not exhaustive concurrency, lifecycle or penetration-test coverage.

| Helper | Direct assertions added | Dependent policy evidence |
|---|---|---|
| `mac_can_use_legacy_admin_access` | Enterprise denied, unmigrated eligible, missing-identity eligibility does not confer row access | Family student RLS also denies migrated and disabled legacy administrators |
| `mac_can_use_legacy_family_link` | Canonical guardian replacement, disabled identity denial, unmigrated eligibility, missing-identity conjunction | Family student RLS excludes unrelated students and disabled identities even without guardian records |
| `mac_is_enterprise_user` | Active identity true; legacy, disabled and missing identity false | Identity classification is not tenant authority |
| `mac_family_can_view_organization` | Assigned organization allowed; unassigned, revoked role, disabled identity and missing identity denied | Organization/site SELECT policies use this predicate; student access separately requires guardian relationship |
| `mac_tutor_can_view_organization` | Own organization allowed; foreign organization and missing identity denied | Organization and site label policies; student access separately requires assigned-student predicate |
| `mac_tutor_owns_session` | Own historical session allowed; another tutor session and missing identity denied | Tutor suite allows own notes and denies another tutor session notes |
| `mac_is_active_educator_scope` | Own organization allowed; foreign organization and missing identity denied | Organization/site labels only; this helper is not classroom ownership |
| `mac_educator_can_access_student` | Enrolled student allowed; student outside classroom and missing identity denied | Educator RLS selects assigned rows and denies other classroom writes |
| `mac_is_organization_admin` | Own tenant admin allowed; teacher, foreign tenant and missing identity denied | Organization administration RLS and guarded enrollment RPC |
| `mac_is_site_classroom_admin` | Own site classroom allowed; another site and mismatched tenant denied | Site operations suite hides other site rows and rejects another site enrollment |

Direct tests: [Family](../../supabase/tests/family_student_access.test.sql), [Tutor](../../supabase/tests/tutor_data_access.test.sql), [Educator](../../supabase/tests/educator_data_access.test.sql), [site operations](../../supabase/tests/site_scoped_operations_access.test.sql).

Source paths: legacy helpers in `20260827011521_enforce_family_student_access.sql`; family labels in `20260830235418_add_family_workspace_access.sql`; tutor scope/session helpers in `20260829221604_link_tutor_profiles_to_assignments.sql`; educator labels in `20260901104500_add_educator_scope_name_access.sql`; educator student helper in `20260903125500_align_educator_rls_tenant_calendar.sql`; site classroom helper in `20260828123000_enforce_site_scoped_operations.sql`; enterprise identity in `20260808194906_enterprise_authorization_rls.sql`; organization admin in `20260825203000_enforce_tenant_context.sql`.

## Proposed decisions — not accepted

Standing engineering/merge approval is not interpreted as acceptance of these product/privacy policies. No security warning is globally dismissed.

| Decision | Recommendation | Acceptance condition / review trigger |
|---|---|---|
| Legacy administration and family links | Retain temporarily only for existing unmigrated identities. Enterprise users must not regain legacy administration; disabled users must not regain family access. Eligibility helpers must remain combined with self identity/ownership. | Inventory remaining legacy identities and every effective caller before retirement. Record George’s transition-policy decision. Review on identity provisioning or RLS changes; retire after the inventory reaches zero and regression checks pass. No retirement date is invented. |
| Organization-wide calendar metadata | Accept same-organization date lookup, including another site, as the narrowly scoped metadata contract implemented in PR #53. It returns a date or NULL, not student/classroom records. | George/product owner confirms this disclosure is intended. Re-review if payload expands beyond dates or tenant authorization changes. Cross-organization denial and underlying row isolation remain mandatory. |
| Historical tutor relationships | Do not certify indefinite access solely because a past session exists. Define whether a currently active tutor should retain access to the assigned student’s record after the last session, and for how long. | George/privacy owner supplies the retention boundary. Until then, current behavior is documented and regression-tested but not accepted for broader certification. Any restriction needs a separate migration and tests for historical notes versus current student data. |

The historical-session assertion protects against accidental behavior changes while a decision is pending; it is not endorsement of indefinite retention. Legacy inventory and effective-caller review remain open. Broader certification also needs current alias and post-hardening role-browser evidence, and master M1/Vocabulary acceptance reconciliation.
