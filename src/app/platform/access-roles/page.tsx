import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

function formatRole(roleKey: string) {
  return roleKey
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function formatDate(value: string | null) {
  if (!value) {
    return "No expiration";
  }

  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(new Date(value));
}

export default async function PlatformAccessRolesPage() {
  await requirePlatformAdmin();

  const supabase = await createClient();

  const { data: assignments, error } = await supabase
    .from("role_assignments")
    .select(
      `
        id,
        role_key,
        status,
        valid_from,
        valid_until,
        organization_id,
        site_id,
        user:users (
          id,
          person:people (
            first_name,
            last_name,
            preferred_name,
            primary_email
          )
        ),
        organization:organizations (
          id,
          name
        ),
        site:sites (
          id,
          name
        )
      `
    )
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(`Unable to load role assignments: ${error.message}`);
  }

  return (
    <AdminShell activeItem="access">
      <div className="grid gap-8">
        <section className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
              Platform administration
            </p>

            <h2 className="mt-2 text-3xl font-bold tracking-tight text-slate-950">
              Access & Roles
            </h2>

            <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
              Review role assignments, authorization scope, and access status
              across MAC Learn.
            </p>
          </div>

          <Link
            href="/platform"
            className="text-sm font-semibold text-slate-700 hover:text-slate-950"
          >
            Back to dashboard
          </Link>
        </section>

        <section className="rounded-2xl border border-slate-200 bg-white shadow-sm">
          {assignments.length === 0 ? (
            <div className="p-6 text-sm text-slate-600">
              No role assignments are currently configured.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead className="border-b border-slate-200 bg-slate-50">
                  <tr>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      User
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Role
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Scope
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Organization
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Site
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Status
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Valid From
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Valid Until
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-slate-200">
                  {assignments.map((assignment) => {
                    const user = Array.isArray(assignment.user)
                      ? assignment.user[0]
                      : assignment.user;

                    const personValue = user?.person;
                    const person = Array.isArray(personValue)
                      ? personValue[0]
                      : personValue;

                    const organization = Array.isArray(assignment.organization)
                      ? assignment.organization[0]
                      : assignment.organization;

                    const site = Array.isArray(assignment.site)
                      ? assignment.site[0]
                      : assignment.site;

                    const fullName = person
                      ? `${person.first_name} ${person.last_name}`
                      : "Unknown user";

                    const displayName =
                      person?.preferred_name?.trim() || fullName;

                    const scope = assignment.site_id
                      ? "Site"
                      : assignment.organization_id
                        ? "Organization"
                        : "Platform-wide";

                    return (
                      <tr key={assignment.id}>
                        <td className="px-6 py-4">
                          <p className="font-semibold text-slate-950">
                            {displayName}
                          </p>
                          <p className="mt-1 text-xs text-slate-500">
                            {person?.primary_email ?? user?.id ?? "Unavailable"}
                          </p>
                        </td>

                        <td className="px-6 py-4 font-medium text-slate-700">
                          {formatRole(assignment.role_key)}
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {scope}
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {organization?.name ?? "—"}
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {site?.name ?? "—"}
                        </td>

                        <td className="px-6 py-4">
                          <span className="inline-flex rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold capitalize text-slate-700">
                            {assignment.status}
                          </span>
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {formatDate(assignment.valid_from)}
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {formatDate(assignment.valid_until)}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </AdminShell>
  );
}
