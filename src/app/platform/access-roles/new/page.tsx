import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

import { RoleAssignmentForm } from "./RoleAssignmentForm";

export default async function NewPlatformRoleAssignmentPage() {
  await requirePlatformAdmin();

  const supabase = await createClient();

  const [
    { data: users, error: usersError },
    { data: organizations, error: organizationsError },
    { data: sites, error: sitesError },
  ] = await Promise.all([
    supabase
      .from("users")
      .select(
        `
          id,
          account_status,
          person:people (
            first_name,
            last_name,
            preferred_name,
            primary_email
          )
        `
      )
      .eq("account_status", "active")
      .order("created_at", { ascending: true }),

    supabase
      .from("organizations")
      .select("id, name, status")
      .order("name", { ascending: true }),

    supabase
      .from("sites")
      .select("id, name, organization_id, status")
      .order("name", { ascending: true }),
  ]);

  if (usersError) {
    throw new Error(`Unable to load users: ${usersError.message}`);
  }

  if (organizationsError) {
    throw new Error(
      `Unable to load organizations: ${organizationsError.message}`
    );
  }

  if (sitesError) {
    throw new Error(`Unable to load sites: ${sitesError.message}`);
  }

  const userOptions = users.map((user) => {
    const personValue = user.person;

    const person = Array.isArray(personValue)
      ? personValue[0]
      : personValue;

    const fullName = person
      ? `${person.first_name} ${person.last_name}`
      : "Unnamed user";

    const displayName =
      person?.preferred_name?.trim() || fullName;

    const secondaryIdentity =
      person?.primary_email ?? user.id;

    return {
      id: user.id,
      label: `${displayName} — ${secondaryIdentity}`,
    };
  });

  const organizationOptions = organizations.map(
    (organization) => ({
      id: organization.id,
      label:
        organization.status === "active"
          ? organization.name
          : `${organization.name} (${organization.status})`,
    })
  );

  const siteOptions = sites.map((site) => ({
    id: site.id,
    organizationId: site.organization_id,
    label:
      site.status === "active"
        ? site.name
        : `${site.name} (${site.status})`,
  }));

  return (
    <AdminShell activeItem="access">
      <div className="grid gap-8">
        <section className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
              Platform administration
            </p>

            <h2 className="mt-2 text-3xl font-bold tracking-tight text-slate-950">
              Create Role Assignment
            </h2>

            <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
              Assign an active MAC Learn user a role and authorization
              scope. Database constraints and Row Level Security remain
              authoritative.
            </p>
          </div>

          <Link
            href="/platform/access-roles"
            className="text-sm font-semibold text-slate-700 hover:text-slate-950"
          >
            Back to Access & Roles
          </Link>
        </section>

        <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <RoleAssignmentForm
            users={userOptions}
            organizations={organizationOptions}
            sites={siteOptions}
          />
        </section>
      </div>
    </AdminShell>
  );
}