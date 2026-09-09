# MAC Learn Migration Reconciliation Manifest

Status: Production-equivalent clean replay revalidated after the Vocabulary Studio merge. PR #48 remains unapplied to production.

Canonical-source policy: GitHub source-controlled migration SQL is the replay authority, subject to schema-equivalence verification against production. Production-only migrations must be restored with their original production versions and semantics before any metadata repair is proposed.

## Classification summary

- MATCH: 11 migrations after excluding the known baseline content drift.
- CONTENT DRIFT: 1 migration (`20260808175035_baseline_existing_mac_mvp`).
- RESTORED FROM PRODUCTION: 4 MAC READS audio migrations.
- VERSION-ORDER DRIFT: 26 logical migrations whose production version differs from the GitHub canonical version.

## Content drift

| Production version | Production name | Canonical GitHub version | Classification | Notes |
|---|---|---|---|---|
| 20260808175035 | baseline_existing_mac_mvp | 20260808175035 | CONTENT DRIFT | Production metadata stores a diagnostic SELECT against legacy tables; GitHub stores the actual replay-safe schema baseline. |

## Restored production-only migrations

| Production version | Name | Canonical version | Classification | Dependency placement |
|---|---|---|---|---|
| 20260829150630 | mac_reads_audio_pilot | 20260829150630 | RESTORED FROM PRODUCTION | Self-contained audio registry; after `activate_invited_enterprise_users`, before later invitation/service-role work. |
| 20260829150650 | mac_reads_audio_registry_rls_policy | 20260829150650 | RESTORED FROM PRODUCTION | Depends only on `mac_reads_audio_assets`. |
| 20260829150713 | mac_reads_audio_bucket | 20260829150713 | RESTORED FROM PRODUCTION | Depends on Supabase Storage schema; no MAC Learn application-table dependency. |
| 20260829150719 | mac_reads_audio_public_route_keys | 20260829150719 | RESTORED FROM PRODUCTION | Depends only on `mac_reads_audio_assets` and seeded pilot rows. |

## Version/order drift mapping

| Production version | Migration name | Canonical GitHub version | Dependency/order assessment |
|---|---|---|---|
| 20260829203656 | activate_invited_enterprise_users | 20260828130000 | Safe in GitHub order; depends on enterprise identity foundation already established. |
| 20260829214512 | grant_invitation_service_role_access | 20260829211313 | Must follow invitation activation/RPC objects; GitHub order preserves that dependency. |
| 20260829225814 | identity_rbac_security_hardening | 20260826201603 | Safe in GitHub order; hardens identity/RBAC foundation before workspace-specific policies. |
| 20260829225822 | enforce_user_workspace_access | 20260827010000 | Depends on identity/RBAC helpers; GitHub order is dependency-correct. |
| 20260829230830 | enforce_family_student_access | 20260827011521 | Depends on enterprise guardian/student relationships; GitHub order is dependency-correct. |
| 20260829230840 | enforce_tutor_data_access | 20260828090000 | Depends on tutor/role foundation; GitHub order is dependency-correct. |
| 20260829230848 | link_tutor_profiles_to_assignments | 20260829221604 | Must follow Tutor access and assignment structures. |
| 20260830000927 | grant_tutor_authenticated_read_access | 20260829235710 | Must follow Tutor RLS policies; grants do not establish authorization by themselves. |
| 20260830002019 | grant_authenticated_profile_read_access | 20260830001115 | Must follow profile RLS policy establishment. |
| 20260830102957 | enable_tutor_operational_workflows | 20260830004003 | Must follow Tutor access/grants and assignment linkage. |
| 20260830193941 | add_student_enrollment_workflow | 20260830173035 | Depends on enterprise student/guardian/site foundation and authorization helpers. |
| 20260830231633 | allow_canonical_sessions_without_legacy_parent | 20260830224500 | Must follow canonical enrollment/guardian relationships. |
| 20260830231646 | validate_canonical_sessions_parent_reference | 20260830224600 | Must immediately follow nullable legacy parent constraint replacement. |
| 20260831120338 | add_family_workspace_access | 20260830235418 | Depends on family/student relationship authorization. |
| 20260831142741 | complete_elapsed_sessions_from_notes | 20260831135200 | Depends on sessions/session notes and Tutor workflow model. |
| 20260831160406 | enforce_educator_data_access | 20260828103000 | Establishes educator data model before later Educator workspace RPCs; GitHub order is dependency-correct. |
| 20260831160414 | enforce_student_data_access | 20260828113000 | Establishes student learning-data authorization before Student workspace access. |
| 20260831160423 | enforce_site_scoped_operations | 20260828123000 | Depends on organization/site/role authorization context. |
| 20260831160431 | add_student_workspace_access | 20260831153000 | Depends on student data access plus canonical student identity linkage. |
| 20260901122442 | invite_existing_student_login | 20260901090000 | Depends on canonical enrollment and invitation infrastructure. |
| 20260905165222 | add_educator_scope_name_access | 20260901104500 | Depends on Educator authorization and tenant scope helpers. |
| 20260905165232 | add_classroom_calendar_date | 20260902164000 | Must precede Educator paging RPCs that consume tenant-calendar dates. |
| 20260905165240 | add_educator_workspace_page_rpcs | 20260902165000 | Depends on classroom calendar helper and Educator access model. |
| 20260905165248 | align_educator_rls_tenant_calendar | 20260903125500 | Depends on classroom calendar semantics and existing Educator RLS. |
| 20260905165256 | align_educator_assignment_tenant_calendar | 20260903163500 | Depends on tenant-calendar helper and assignment lifecycle policies. |
| 20260905165305 | optimize_educator_workspace_scope | 20260905120500 | Final optimization; depends on all earlier Educator paging/access objects. |

## Canonical replay sequence decision

1. Use GitHub migration timestamps/order as canonical for all source-controlled migrations.
2. Insert the four restored audio migrations at their original versions (`20260829150630` through `20260829150719`).
3. Do not rewrite later GitHub timestamps to match production. The repository order is dependency-correct and is already exercised by fresh-database CI.
4. Do not modify production `supabase_migrations.schema_migrations` until a clean replay and schema-equivalence audit succeed.
5. Keep the merged Vocabulary Studio migration (`20260909143000_add_vocabulary_catalog.sql`) in the canonical chain before the final ACL-equivalence migration.

## Current production-equivalence evidence

The clean replay generated from current `main` plus PR #48 on 2026-09-09 matched current production for every required normalized comparison:

- Public table ACLs: 615 rows, including exactly 77 API-role `MAINTAIN` grants.
- Public column ACLs: 5 rows.
- Public function ACLs: 107 rows, excluding the expected production-only `rls_auto_enable()` helper.
- Public constraints: 173.
- Shared public function definitions and security attributes: 57.
- Public RLS policies: 83; table RLS states: 29.
- Public indexes: 101; columns: 315; enum labels: 29; triggers: 25.
- MAC READS audio Storage bucket configuration: exact match.
- Migration inventory: all 44 production versions and names exactly match the branch prefix; `20260909171010_finalize_production_acl_equivalence.sql` is the sole pending migration.
- Clean-replay schema SHA-256: `a72d5363ae72fba4f2c2388046d5b2aaf69d2f1f368172e4c07fa6e5c4cf82e0`.

**PRODUCTION-EQUIVALENT REPLAY: PASS**

## Remaining certification gates

- Normal Quality and Vercel checks on the instrumentation-free PR head.
- Fresh independent Codex review on that same head.
- Explicit merge approval after every check is clean.
