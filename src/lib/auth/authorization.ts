import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type MacRole =
  | "student"
  | "guardian"
  | "tutor"
  | "teacher"
  | "academic_lead"
  | "site_admin"
  | "organization_admin"
  | "platform_support"
  | "platform_admin";

export type AuthorizationScope = {
  organizationId?: string | null;
  siteId?: string | null;
};

export type TenantContext = {
  organizationId: string;
  siteId: string | null;
};

export async function requireAuthenticatedUser() {
  const supabase = await createClient();

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    redirect("/login");
  }

  return { supabase, user };
}

export async function isEnterpriseUser() {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_is_enterprise_user");

  if (error) {
    return false;
  }

  return data === true;
}

export async function hasRole(
  role: MacRole,
  scope: AuthorizationScope = {}
) {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_has_role", {
    requested_role: role,
    requested_organization_id: scope.organizationId ?? null,
    requested_site_id: scope.siteId ?? null,
  });

  if (error) {
    return false;
  }

  return data === true;
}

export async function hasAnyRole(roles: readonly MacRole[]) {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_current_user_roles");

  if (error) {
    return false;
  }

  const assignments = (data ?? []) as { role_key: string }[];

  return assignments.some((assignment) =>
    roles.includes(assignment.role_key as MacRole)
  );
}

export async function isPlatformAdmin() {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_is_platform_admin");

  if (error) {
    return false;
  }

  return data === true;
}

export async function isOrganizationAdmin(organizationId: string) {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_is_organization_admin", {
    requested_organization_id: organizationId,
  });

  if (error) {
    return false;
  }

  return data === true;
}

export async function isSiteAdmin(
  organizationId: string,
  siteId: string
) {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_is_site_admin", {
    requested_organization_id: organizationId,
    requested_site_id: siteId,
  });

  if (error) {
    return false;
  }

  return data === true;
}

export async function canAccessOrganization(organizationId: string) {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc(
    "mac_can_access_organization",
    {
      requested_organization_id: organizationId,
    }
  );

  if (error) {
    return false;
  }

  return data === true;
}

export async function canAccessSite(
  organizationId: string,
  siteId: string
) {
  const { supabase } = await requireAuthenticatedUser();

  const { data, error } = await supabase.rpc("mac_can_access_site", {
    requested_organization_id: organizationId,
    requested_site_id: siteId,
  });

  if (error) {
    return false;
  }

  return data === true;
}

export async function requireTenantContext(
  organizationId: string,
  siteId: string | null = null
): Promise<TenantContext> {
  const allowed = siteId
    ? await canAccessSite(organizationId, siteId)
    : await canAccessOrganization(organizationId);

  if (!allowed) {
    redirect("/unauthorized");
  }

  return {
    organizationId,
    siteId,
  };
}

export async function requireEnterpriseUser() {
  const allowed = await isEnterpriseUser();

  if (!allowed) {
    redirect("/unauthorized");
  }
}

export async function requireRole(
  role: MacRole,
  scope: AuthorizationScope = {}
) {
  const allowed = await hasRole(role, scope);

  if (!allowed) {
    redirect("/unauthorized");
  }
}

export async function requireAnyRole(roles: readonly MacRole[]) {
  const allowed = await hasAnyRole(roles);

  if (!allowed) {
    redirect("/unauthorized");
  }
}

export async function requirePlatformAdmin() {
  const allowed = await isPlatformAdmin();

  if (!allowed) {
    redirect("/unauthorized");
  }
}

export async function requireOrganizationAdmin(
  organizationId: string
) {
  const allowed = await isOrganizationAdmin(organizationId);

  if (!allowed) {
    redirect("/unauthorized");
  }
}

export async function requireSiteAdmin(
  organizationId: string,
  siteId: string
) {
  const allowed = await isSiteAdmin(organizationId, siteId);

  if (!allowed) {
    redirect("/unauthorized");
  }
}
