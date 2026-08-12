import type { User } from "@supabase/supabase-js";

import type { MacRole } from "@/lib/auth/authorization";
import { requireAuthenticatedUser } from "@/lib/auth/authorization";

export type MacRoleAssignment = {
  role: MacRole;
  organizationId: string | null;
  siteId: string | null;
};

export type MacAuthorizationContext = {
  user: User;
  roles: MacRoleAssignment[];
  primaryRole: MacRole | null;
};

type CurrentUserRoleRow = {
  role_key: string;
  organization_id: string | null;
  site_id: string | null;
};

const MAC_ROLES: readonly MacRole[] = [
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

function isMacRole(value: string): value is MacRole {
  return MAC_ROLES.includes(value as MacRole);
}

export async function getAuthorizationContext(): Promise<MacAuthorizationContext> {
  const { supabase, user } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_current_user_roles");

  if (error) {
    throw new Error(
      `Unable to load MAC Learn authorization context: ${error.message}`
    );
  }

  const rows = (data ?? []) as CurrentUserRoleRow[];

  const roles: MacRoleAssignment[] = rows
    .filter((row) => isMacRole(row.role_key))
    .map((row) => ({
      role: row.role_key as MacRole,
      organizationId: row.organization_id,
      siteId: row.site_id,
    }));

  return {
    user,
    roles,
    primaryRole: roles[0]?.role ?? null,
  };
}