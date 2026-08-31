import type { MacRole } from "@/lib/auth/authorization";
import type { MacRoleAssignment } from "@/lib/auth/context";

export function resolveWorkspacePath(
  assignment: MacRoleAssignment
): string | null {
  switch (assignment.role) {
    case "platform_admin":
      return "/platform";
    case "organization_admin":
      return assignment.organizationId
        ? `/organizations/${assignment.organizationId}`
        : null;
    case "site_admin":
      return assignment.organizationId && assignment.siteId
        ? `/organizations/${assignment.organizationId}/sites/${assignment.siteId}`
        : null;
    case "tutor":
      return "/tutor";
    case "guardian":
      return "/family";
    default:
      return null;
  }
}

export const ENTERPRISE_WORKSPACE_ROLES: readonly MacRole[] = [
  "platform_admin",
  "platform_support",
  "organization_admin",
  "site_admin",
  "academic_lead",
  "teacher",
  "tutor",
  "guardian",
];
