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

type OrganizationConfigurationActionState = {
  error: string | null;
};

export type RoleAssignmentSearchKind =
  | "user"
  | "organization"
  | "site";

export type RoleAssignmentSearchOption = {
  id: string;
  label: string;
};

type RoleAssignmentSearchResult = {
  options: RoleAssignmentSearchOption[];
  error: string | null;
};

const SEARCH_RESULT_LIMIT = 20;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

function getSupportedLocales(formData: FormData) {
  const value = getRequiredString(formData, "supported_locales");
  const locales = value
    .split(",")
    .map((locale) => locale.trim())
    .filter(Boolean)
    .map((locale) => {
      try {
        return Intl.getCanonicalLocales(locale)[0];
      } catch {
        throw new Error(
          "Supported locales must be comma-separated valid BCP 47 locale tags, such as en-US, es-419, or zh-Hant-TW."
        );
      }
    });

  if (locales.length === 0) {
    throw new Error("At least one supported locale is required.");
  }

  return [...new Set(locales)];
}

function getCanonicalLocale(formData: FormData, fieldName: string) {
  const value = getRequiredString(formData, fieldName);

  try {
    return Intl.getCanonicalLocales(value)[0];
  } catch {
    throw new Error(`${fieldName} must be a valid BCP 47 locale tag.`);
  }
}

function getCanonicalTimezone(formData: FormData) {
  const value = getRequiredString(formData, "default_timezone");

  try {
    return new Intl.DateTimeFormat("en-US", { timeZone: value })
      .resolvedOptions().timeZone;
  } catch {
    throw new Error(
      "default_timezone must be a valid IANA timezone, such as America/New_York."
    );
  }
}

export async function saveOrganizationConfiguration(
  _previousState: OrganizationConfigurationActionState,
  formData: FormData
): Promise<OrganizationConfigurationActionState> {
  await requirePlatformAdmin();

  try {
    const organizationId = getRequiredString(formData, "organization_id");
    const defaultTimezone = getCanonicalTimezone(formData);
    const defaultLocale = getCanonicalLocale(formData, "default_locale");
    const supportedLocales = getSupportedLocales(formData);
    const academicYearStartMonth = Number(
      getRequiredString(formData, "academic_year_start_month")
    );

    if (!Number.isInteger(academicYearStartMonth) || academicYearStartMonth < 1 || academicYearStartMonth > 12) {
      throw new Error("Academic-year start month must be between 1 and 12.");
    }

    if (!supportedLocales.includes(defaultLocale)) {
      throw new Error("The default locale must be included in supported locales.");
    }

    const supabase = await createClient();
    const { error } = await supabase
      .from("organization_configurations")
      .update({
        default_timezone: defaultTimezone,
        default_locale: defaultLocale,
        supported_locales: supportedLocales,
        academic_year_start_month: academicYearStartMonth,
        attendance_required: formData.get("attendance_required") === "on",
      })
      .eq("organization_id", organizationId);

    if (error) {
      throw new Error(`Unable to save organization configuration: ${error.message}`);
    }
  } catch (error) {
    return { error: getErrorMessage(error) };
  }

  revalidatePath("/platform/organizations");
  revalidatePath(`/platform/organizations/${formData.get("organization_id")}/configuration`);

  return { error: null };
}

export async function logout() {
  const supabase = await createClient();

  await supabase.auth.signOut();

  redirect("/login");
}

export async function searchRoleAssignmentOptions(
  kind: RoleAssignmentSearchKind,
  query: string,
  organizationId: string | null = null
): Promise<RoleAssignmentSearchResult> {
  await requirePlatformAdmin();

  const searchTerm = query
    .replace(/[,%()]/g, " ")
    .trim()
    .slice(0, 100);

  if (searchTerm.length < 2) {
    return { options: [], error: null };
  }

  const supabase = await createClient();

  if (kind === "user") {
    if (UUID_PATTERN.test(searchTerm)) {
      const { data: user, error } = await supabase
        .from("users")
        .select("id, account_status")
        .eq("id", searchTerm)
        .eq("account_status", "active")
        .maybeSingle();

      if (error) {
        return { options: [], error: error.message };
      }

      return {
        options: user
          ? [{ id: user.id, label: user.id }]
          : [],
        error: null,
      };
    }

    const pattern = `%${searchTerm}%`;
    const { data: people, error } = await supabase
      .from("people")
      .select(
        `
          first_name,
          last_name,
          preferred_name,
          primary_email,
          user:users!inner (
            id,
            account_status
          )
        `
      )
      .eq("user.account_status", "active")
      .or(
        `first_name.ilike.${pattern},last_name.ilike.${pattern},preferred_name.ilike.${pattern},primary_email.ilike.${pattern}`
      )
      .order("last_name", { ascending: true })
      .order("first_name", { ascending: true })
      .limit(SEARCH_RESULT_LIMIT);

    if (error) {
      return { options: [], error: error.message };
    }

    return {
      options: people.flatMap((person) => {
        const userValue = person.user;
        const user = Array.isArray(userValue)
          ? userValue[0]
          : userValue;

        if (!user) {
          return [];
        }

        const fullName =
          `${person.first_name} ${person.last_name}`;
        const displayName =
          person.preferred_name?.trim() || fullName;

        return [{
          id: user.id,
          label: `${displayName} — ${person.primary_email ?? user.id}`,
        }];
      }),
      error: null,
    };
  }

  if (kind === "organization") {
    const pattern = `%${searchTerm}%`;
    const { data, error } = await supabase
      .from("organizations")
      .select("id, name, slug")
      .eq("status", "active")
      .or(`name.ilike.${pattern},slug.ilike.${pattern}`)
      .order("name", { ascending: true })
      .limit(SEARCH_RESULT_LIMIT);

    return {
      options: error
        ? []
        : data.map((organization) => ({
            id: organization.id,
            label: `${organization.name} — ${organization.slug}`,
          })),
      error: error?.message ?? null,
    };
  }

  if (!organizationId) {
    return { options: [], error: null };
  }

  const pattern = `%${searchTerm}%`;
  const { data, error } = await supabase
    .from("sites")
    .select("id, name, code")
    .eq("organization_id", organizationId)
    .eq("status", "active")
    .or(`name.ilike.${pattern},code.ilike.${pattern}`)
    .order("name", { ascending: true })
    .limit(SEARCH_RESULT_LIMIT);

  return {
    options: error
      ? []
      : data.map((site) => ({
          id: site.id,
          label: site.code
            ? `${site.name} — ${site.code}`
            : site.name,
        })),
    error: error?.message ?? null,
  };
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

type RoleAssignmentLifecycleOperation =
  | "revoke"
  | "expire"
  | "renew";

async function runRoleAssignmentLifecycleOperation(
  operation: RoleAssignmentLifecycleOperation,
  formData: FormData
) {
  await requirePlatformAdmin();

  const assignmentId = getOptionalString(formData, "assignment_id");
  const reason = getOptionalString(formData, "reason");

  if (!assignmentId || !UUID_PATTERN.test(assignmentId)) {
    redirect(
      "/platform/access-roles?lifecycle_error=Invalid%20assignment."
    );
  }

  if (!reason) {
    redirect(
      "/platform/access-roles?lifecycle_error=A%20reason%20is%20required."
    );
  }

  if (reason.length > 500) {
    redirect(
      "/platform/access-roles?lifecycle_error=The%20reason%20must%20be%20500%20characters%20or%20fewer."
    );
  }

  const supabase = await createClient();
  let error: { message: string } | null = null;

  if (operation === "revoke") {
    ({ error } = await supabase.rpc("mac_revoke_role_assignment", {
      p_assignment_id: assignmentId,
      p_reason: reason,
    }));
  } else if (operation === "expire") {
    ({ error } = await supabase.rpc("mac_expire_role_assignment", {
      p_assignment_id: assignmentId,
      p_reason: reason,
    }));
  } else {
    const validUntilValue = getOptionalString(
      formData,
      "valid_until"
    );

    let validUntil: string | null = null;

    if (validUntilValue) {
      const parsedValidUntil = new Date(
        `${validUntilValue}T23:59:59.999Z`
      );

      if (Number.isNaN(parsedValidUntil.getTime())) {
        redirect(
          "/platform/access-roles?lifecycle_error=Invalid%20renewal%20date."
        );
      }

      validUntil = parsedValidUntil.toISOString();
    }

    ({ error } = await supabase.rpc("mac_renew_role_assignment", {
      p_assignment_id: assignmentId,
      p_new_valid_until: validUntil,
      p_reason: reason,
    }));
  }

  if (error) {
    const message = encodeURIComponent(error.message.slice(0, 180));
    redirect(`/platform/access-roles?lifecycle_error=${message}`);
  }

  revalidatePath("/platform/access-roles");
  redirect(`/platform/access-roles?${operation}=1`);
}

export async function revokeRoleAssignment(formData: FormData) {
  await runRoleAssignmentLifecycleOperation("revoke", formData);
}

export async function expireRoleAssignment(formData: FormData) {
  await runRoleAssignmentLifecycleOperation("expire", formData);
}

export async function renewRoleAssignment(formData: FormData) {
  await runRoleAssignmentLifecycleOperation("renew", formData);
}
