"use server";

import { revalidatePath } from "next/cache";

import { requireOrganizationAdmin, requirePlatformAdmin } from "@/lib/auth/authorization";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

export type EnrollmentActionState = {
  active: boolean;
  enrolled: boolean;
  error: string | null;
  guardianInvited: boolean;
};

export type EnrollmentSearchOption = { id: string; label: string };
export type EnrollmentSearchResult = {
  options: EnrollmentSearchOption[];
  error: string | null;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function required(formData: FormData, name: string) {
  const value = formData.get(name);
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`${name.replaceAll("_", " ")} is required.`);
  }
  return value.trim();
}

function optional(formData: FormData, name: string) {
  const value = formData.get(name);
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function message(error: unknown) {
  return error instanceof Error ? error.message : "Unable to enroll student.";
}

export async function searchEnrollmentOptions(
  kind: "organization" | "site" | "guardian",
  query: string,
  organizationId: string | null = null,
  siteId: string | null = null
): Promise<EnrollmentSearchResult> {
  await requirePlatformAdmin();
  const term = query.replace(/[,%()]/g, " ").trim().slice(0, 100);
  if (term.length < 2) return { options: [], error: null };
  const supabase = kind === "guardian" ? createAdminClient() : await createClient();
  const pattern = `%${term}%`;

  if (kind === "organization") {
    const { data, error } = await supabase
      .from("organizations")
      .select("id, name, slug")
      .eq("status", "active")
      .or(`name.ilike.${pattern},slug.ilike.${pattern}`)
      .order("name")
      .limit(20);
    return {
      options: (data ?? []).map((row) => ({ id: row.id, label: `${row.name} — ${row.slug}` })),
      error: error?.message ?? null,
    };
  }

  if (!organizationId || !UUID_PATTERN.test(organizationId)) {
    return { options: [], error: null };
  }

  if (kind === "site") {
    const { data, error } = await supabase
      .from("sites")
      .select("id, name, code")
      .eq("organization_id", organizationId)
      .eq("status", "active")
      .or(`name.ilike.${pattern},code.ilike.${pattern}`)
      .order("name")
      .limit(20);
    return {
      options: (data ?? []).map((row) => ({
        id: row.id,
        label: row.code ? `${row.name} — ${row.code}` : row.name,
      })),
      error: error?.message ?? null,
    };
  }

  if (!siteId || !UUID_PATTERN.test(siteId)) {
    return { options: [], error: null };
  }

  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("people")
    .select("first_name, last_name, primary_email, user:users!inner(id, account_status, profiles!inner(organization_id), role_assignments!inner(organization_id, site_id, role_key, status, valid_from, valid_until))")
    .eq("user.profiles.organization_id", organizationId)
    .eq("user.role_assignments.organization_id", organizationId)
    .eq("user.role_assignments.role_key", "guardian")
    .eq("user.role_assignments.status", "active")
    .lte("user.role_assignments.valid_from", now)
    .or(`site_id.is.null,site_id.eq.${siteId}`, { referencedTable: "user.role_assignments" })
    .or(`valid_until.is.null,valid_until.gt.${now}`, { referencedTable: "user.role_assignments" })
    .in("user.account_status", ["active", "invited"])
    .or(`first_name.ilike.${pattern},last_name.ilike.${pattern},primary_email.ilike.${pattern}`)
    .order("last_name")
    .order("first_name")
    .limit(20);

  return {
    options: error
      ? []
      : (data ?? []).flatMap((person) => {
          const users = Array.isArray(person.user) ? person.user : [person.user];
          return users.filter(Boolean).map((user) => ({
            id: user.id,
            label: `${person.first_name} ${person.last_name} — ${person.primary_email ?? user.id} (${user.account_status})`,
          }));
        }),
    error: error?.message ?? null,
  };
}

export async function enrollStudent(
  _previous: EnrollmentActionState,
  formData: FormData
): Promise<EnrollmentActionState> {
  let invitedGuardianUserId: string | null = null;
  let adminClient: ReturnType<typeof createAdminClient> | null = null;

  try {
    const firstName = required(formData, "first_name");
    const lastName = required(formData, "last_name");
    const gradeLevel = required(formData, "grade_level");
    const schoolName = optional(formData, "school_name") ?? "";
    const organizationId = required(formData, "organization_id");
    const siteId = required(formData, "site_id");
    const enrollmentStartDate = required(formData, "enrollment_start_date");
    const enterpriseStatus = required(formData, "enterprise_status");
    const guardianMode = required(formData, "guardian_mode");
    const relationshipType = required(formData, "relationship_type");

    if (![organizationId, siteId].every((value) => UUID_PATTERN.test(value))) {
      throw new Error("Organization and site selections are invalid.");
    }
    if (![firstName, lastName, gradeLevel].every((value) => value.length <= 100)) {
      throw new Error("Student name and grade fields must be 100 characters or fewer.");
    }
    if (schoolName.length > 200) throw new Error("School name must be 200 characters or fewer.");
    if (!/^\d{4}-\d{2}-\d{2}$/.test(enrollmentStartDate)) {
      throw new Error("Enrollment start date is invalid.");
    }
    if (!['active', 'inactive'].includes(enterpriseStatus)) {
      throw new Error("Enrollment status must be active or inactive.");
    }
    if (!['parent_guardian', 'parent', 'guardian', 'caregiver'].includes(relationshipType)) {
      throw new Error("Guardian relationship type is invalid.");
    }

    await requireOrganizationAdmin(organizationId);
    const supabase = await createClient();
    const [organizationCheck, siteCheck] = await Promise.all([
      supabase.from("organizations").select("id").eq("id", organizationId).eq("status", "active").maybeSingle(),
      supabase.from("sites").select("id, timezone").eq("id", siteId).eq("organization_id", organizationId).eq("status", "active").maybeSingle(),
    ]);
    if (organizationCheck.error || siteCheck.error) {
      throw new Error("Unable to verify the selected organization and site.");
    }
    if (!organizationCheck.data) throw new Error("The selected organization is not active.");
    if (!siteCheck.data) throw new Error("The selected site is not active in this organization.");
    const businessDateParts = new Intl.DateTimeFormat("en-US", {
      timeZone: siteCheck.data.timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(new Date());
    const businessDate = Object.fromEntries(businessDateParts.map((part) => [part.type, part.value]));
    const businessToday = `${businessDate.year}-${businessDate.month}-${businessDate.day}`;
    if (enrollmentStartDate > businessToday) {
      throw new Error("Enrollment start date cannot be in the future.");
    }

    let guardianUserId: string;

    if (guardianMode === "existing") {
      guardianUserId = required(formData, "guardian_user_id");
      if (!UUID_PATTERN.test(guardianUserId)) throw new Error("Select an existing guardian.");
    } else if (guardianMode === "new") {
      const guardianFirstName = required(formData, "guardian_first_name");
      const guardianLastName = required(formData, "guardian_last_name");
      const guardianEmail = required(formData, "guardian_email").toLowerCase();
      if (!EMAIL_PATTERN.test(guardianEmail)) throw new Error("Guardian email is invalid.");
      if (guardianFirstName.length > 100 || guardianLastName.length > 100) {
        throw new Error("Guardian names must be 100 characters or fewer.");
      }
      const appUrl = process.env.NEXT_PUBLIC_APP_URL;
      if (!appUrl) throw new Error("Invitations are unavailable until the application URL is configured.");

      adminClient = createAdminClient();
      const { data: invite, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(
        guardianEmail,
        {
          redirectTo: `${appUrl}/auth/callback`,
          data: { first_name: guardianFirstName, last_name: guardianLastName },
        }
      );
      if (inviteError || !invite.user) {
        throw new Error(`Unable to invite guardian: ${inviteError?.message ?? "unknown error"}`);
      }
      guardianUserId = invite.user.id;
      invitedGuardianUserId = guardianUserId;

      const { data: personId, error: identityError } = await adminClient.rpc(
        "mac_create_invited_enterprise_identity",
        {
          p_user_id: guardianUserId,
          p_first_name: guardianFirstName,
          p_last_name: guardianLastName,
          p_email: guardianEmail,
          p_organization_id: organizationId,
          p_site_id: siteId,
        }
      );
      if (identityError || !personId) {
        throw new Error(`Unable to create guardian identity: ${identityError?.message ?? "unknown error"}`);
      }

      const { error: roleError } = await supabase.from("role_assignments").insert({
        user_id: guardianUserId,
        role_key: "guardian",
        organization_id: organizationId,
        site_id: siteId,
        status: "active",
      });
      if (roleError) throw new Error(`Unable to assign guardian role: ${roleError.message}`);
    } else {
      throw new Error("Choose an existing guardian or invite a new guardian.");
    }

    const { data: studentId, error: enrollmentError } = await supabase.rpc(
      "mac_admin_enroll_student",
      {
        p_first_name: firstName,
        p_last_name: lastName,
        p_grade_level: gradeLevel,
        p_school_name: schoolName,
        p_organization_id: organizationId,
        p_site_id: siteId,
        p_enrollment_start_date: enrollmentStartDate,
        p_enterprise_status: enterpriseStatus,
        p_guardian_user_id: guardianUserId,
        p_relationship_type: relationshipType,
      }
    );
    if (enrollmentError || !studentId) {
      throw new Error(`Unable to enroll student: ${enrollmentError?.message ?? "unknown error"}`);
    }

    revalidatePath("/platform/students");
    revalidatePath("/platform/tutor-operations");
    return { active: enterpriseStatus === "active", enrolled: true, error: null, guardianInvited: guardianMode === "new" };
  } catch (error) {
    let cleanupFailure: string | null = null;
    if (invitedGuardianUserId && adminClient) {
      const { data: cleanupStatus, error: cleanupError } = await adminClient.rpc(
        "mac_cleanup_invited_enterprise_identity",
        { p_user_id: invitedGuardianUserId }
      );
      if (cleanupError) {
        cleanupFailure = `Guardian invitation cleanup failed: ${cleanupError.message}`;
      } else if (cleanupStatus === "cleaned" || cleanupStatus === "missing") {
        const { error: deletionError } = await adminClient.auth.admin.deleteUser(invitedGuardianUserId);
        if (deletionError) {
          cleanupFailure = `Guardian Auth cleanup failed for user ${invitedGuardianUserId}: ${deletionError.message}. Remove this invited Auth user before resending.`;
        }
      } else {
        cleanupFailure = `Guardian invitation cleanup returned an unexpected status for user ${invitedGuardianUserId}. Verify the invited identity before resending.`;
      }
    }
    return {
      active: false,
      enrolled: false,
      error: cleanupFailure ? `${message(error)} ${cleanupFailure}` : message(error),
      guardianInvited: false,
    };
  }
}
