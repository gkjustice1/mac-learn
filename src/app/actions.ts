"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  type MacRole,
  requirePlatformAdmin,
} from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

type RoleAssignmentActionState = {
  error: string | null;
};

const ROLE_KEYS: MacRole[] = [
  "student",
  "guardian",
  "tutor",
  "teacher",
  "academic_lead",
  "site_admin",
  "organization_admin",
  "platform_support",
  "platform_admin",
];

const PLATFORM_ROLES: MacRole[] = [
  "platform_admin",
  "platform_support",
];

const ORGANIZATION_ROLES: MacRole[] = [
  "organization_admin",
  "academic_lead",
];

const SITE_REQUIRED_ROLES: MacRole[] = [
  "site_admin",
];

const OPERATIONAL_ROLES: MacRole[] = [
  "student",
  "guardian",
  "tutor",
  "teacher",
];

function getRequiredString(
  formData: FormData,
  fieldName: string
) {
  const value = formData.get(fieldName);

  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${fieldName} is required.`);
  }

  return value.trim();
}

function getOptionalString(
  formData: FormData,
  fieldName: string
) {
  const value = formData.get(fieldName);

  if (typeof value !== "string") {
    return null;
  }

  const trimmedValue = value.trim();

  return trimmedValue === "" ? null : trimmedValue;
}

function isMacRole(value: string): value is MacRole {
  return ROLE_KEYS.includes(value as MacRole);
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  return "Unable to create role assignment.";
}

export async function logout() {
  const supabase = await createClient();

  await supabase.auth.signOut();

  redirect("/login");
}

export async function createRoleAssignment(
  _previousState: RoleAssignmentActionState,
  formData: FormData
): Promise<RoleAssignmentActionState> {
  await requirePlatformAdmin();

  const supabase = await createClient();

  try {
    const userId = getRequiredString(formData, "user_id");
    const roleValue = getRequiredString(formData, "role_key");

    if (!isMacRole(roleValue)) {
      throw new Error("Invalid MAC Learn role.");
    }

    const roleKey = roleValue;

    let organizationId = getOptionalString(
      formData,
      "organization_id"
    );

    let siteId = getOptionalString(formData, "site_id");

    if (PLATFORM_ROLES.includes(roleKey)) {
      organizationId = null;
      siteId = null;
    } else if (ORGANIZATION_ROLES.includes(roleKey)) {
      if (!organizationId) {
        throw new Error(
          "An organization is required for this role."
        );
      }

      siteId = null;
    } else if (SITE_REQUIRED_ROLES.includes(roleKey)) {
      if (!organizationId || !siteId) {
        throw new Error(
          "An organization and site are required for this role."
        );
      }
    } else if (OPERATIONAL_ROLES.includes(roleKey)) {
      if (!organizationId) {
        throw new Error(
          "An organization is required for this role."
        );
      }
    }

    const { data: userRecord, error: userError } = await supabase
      .from("users")
      .select("id, account_status")
      .eq("id", userId)
      .maybeSingle();

    if (userError) {
      throw new Error(
        `Unable to validate user: ${userError.message}`
      );
    }

    if (!userRecord || userRecord.account_status !== "active") {
      throw new Error(
        "Role assignments can only be created for active users."
      );
    }

    if (organizationId) {
      const {
        data: organization,
        error: organizationError,
      } = await supabase
        .from("organizations")
        .select("id, status")
        .eq("id", organizationId)
        .maybeSingle();

      if (organizationError) {
        throw new Error(
          `Unable to validate organization: ${organizationError.message}`
        );
      }

      if (!organization) {
        throw new Error(
          "The selected organization does not exist."
        );
      }

      if (organization.status !== "active") {
        throw new Error(
          "Role assignments can only be created for active organizations."
        );
      }
    }

    if (siteId) {
      if (!organizationId) {
        throw new Error(
          "A site cannot be assigned without an organization."
        );
      }

      const { data: site, error: siteError } = await supabase
        .from("sites")
        .select("id, organization_id, status")
        .eq("id", siteId)
        .maybeSingle();

      if (siteError) {
        throw new Error(
          `Unable to validate site: ${siteError.message}`
        );
      }

      if (!site) {
        throw new Error("The selected site does not exist.");
      }

      if (site.organization_id !== organizationId) {
        throw new Error(
          "The selected site does not belong to the selected organization."
        );
      }

      if (site.status !== "active") {
        throw new Error(
          "Role assignments can only be created for active sites."
        );
      }
    }

    const { error: insertError } = await supabase
      .from("role_assignments")
      .insert({
        user_id: userId,
        role_key: roleKey,
        organization_id: organizationId,
        site_id: siteId,
        status: "active",
      });

    if (insertError) {
      if (insertError.code === "23505") {
        return {
          error:
            "This user already has an active assignment for this role and scope.",
        };
      }

      throw new Error(
        `Unable to create role assignment: ${insertError.message}`
      );
    }
  } catch (error) {
    return {
      error: getErrorMessage(error),
    };
  }

  revalidatePath("/platform/access-roles");

  redirect("/platform/access-roles?created=1");
}