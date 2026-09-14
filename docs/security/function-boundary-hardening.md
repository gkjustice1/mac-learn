# Function boundary hardening — 2026-09-14

Status: PR #53 merged as 8cb26d0; production migration 20260914152633 applied and verified. Broader security gate remains open; see security-definer-register.md.
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

Supabase Pro confirmed. George enabled leaked-password protection in Auth settings; the live advisor no longer reports the disabled-protection warning. No billing or other password-policy changes were made.
Reference: https://supabase.com/docs/guides/auth/password-security

The clean replay passed 456 assertions in 22 files; Quality and Vercel status passed, and Codex completed without findings. The four production bodies and ACLs match reviewed SQL; denied-access smoke checks passed. Remaining warning dispositions and broader release gates are tracked in security-definer-register.md and ../certification/m1-vocabulary-release-checklist.md. This document does not accept the other advisor warnings as a blanket exception.
