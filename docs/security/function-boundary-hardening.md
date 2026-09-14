# Function boundary hardening — 2026-09-14

Status: branch implementation; production migration and broader security gate pending.
Base: main 85d41b498302654566a0fb3487c90cc09c9e3855.

## Four functions

- `mac_classroom_calendar_date(uuid)` and `mac_relationship_calendar_date(uuid,uuid)` now require an active organization authorization through `mac_can_access_organization`. Missing, mismatched, and unauthorized targets return NULL, including calls without an authenticated identity. Valid targets retain site → organization → UTC timezone precedence.
- Calendar dates are organization metadata, not authorization to read a student or classroom. Same-organization membership permits calendar lookup; existing row policies retain finer assignment/relationship restrictions. Calendar helpers deliberately avoid the student/family/educator visibility functions that depend on them, preventing RLS recursion. Platform administrators remain supported by the organization helper.
- `mac_admin_update_tutor_profile` and `mac_admin_clear_tutor_profile_fields` now authorize before acquiring the tutor row lock and retain the authorization recheck after locking. Existing tenant and replacement-profile checks remain intact.
- Function signatures and ACLs remain compatible. SECURITY DEFINER is retained for protected internal lookups; the advisor's authenticated-executable warning can therefore remain. Warning-count reduction is not the acceptance criterion.

## Regression coverage

- Cross-organization, mismatched, nonexistent, missing-identity, and expired-role calendar lookups.
- Deterministic timezone fallback differing from UTC and educator/RLS dependency execution.
- Negative tutor mutator calls and unchanged authorized administrator behavior.
- Catalog assertions for authorization before and after locking. These are ordering assertions, not a concurrent lock-contention test.
- Full existing database suite covers Student, Family, Educator page RPCs, enrollment, identity, tutor, and ACL dependencies on a clean replay.

## Separate Auth configuration gate

Read-only organization lookup confirms Supabase Pro. Leaked-password protection is supported by this plan, but the available Supabase connector has no Auth-configuration update endpoint. No Auth setting was changed in this branch work.
Enable the leaked-password control in the project's Auth settings, save, and rerun the security advisor to verify `auth_leaked_password_protection` is absent. Do not change password length, signup policy, or billing as part of this request.
Reference: https://supabase.com/docs/guides/auth/password-security

The broader security gate remains open until checks and review pass, the production hardening is deployed and verified, and leaked-password protection is confirmed enabled (or an explicit exception is documented). This document does not accept the other advisor warnings as a blanket exception.
