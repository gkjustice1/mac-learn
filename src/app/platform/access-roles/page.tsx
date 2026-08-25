import Link from "next/link";
import { redirect } from "next/navigation";

import {
  expireRoleAssignment,
  renewRoleAssignment,
  revokeRoleAssignment,
} from "@/app/actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

const PAGE_SIZE = 100;

type PlatformAccessRolesPageProps = {
  searchParams: Promise<{
    page?: string;
    created?: string;
    revoke?: string;
    expire?: string;
    renew?: string;
    lifecycle_error?: string;
  }>;
};

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

export default async function PlatformAccessRolesPage({
  searchParams,
}: PlatformAccessRolesPageProps) {
  await requirePlatformAdmin();

  const resolvedSearchParams = await searchParams;

  const requestedPage = Number.parseInt(
    resolvedSearchParams.page ?? "1",
    10
  );

  const requestedPageNumber =
    Number.isFinite(requestedPage) && requestedPage > 0
      ? requestedPage
      : 1;

  const supabase = await createClient();

  const { count, error: countError } = await supabase
    .from("role_assignments")
    .select("id", { count: "exact", head: true });

  if (countError) {
    throw new Error(
      `Unable to count role assignments: ${countError.message}`
    );
  }

  const totalAssignments = count ?? 0;
  const totalPages = Math.max(
    1,
    Math.ceil(totalAssignments / PAGE_SIZE)
  );

  if (requestedPageNumber > totalPages) {
    redirect(`/platform/access-roles?page=${totalPages}`);
  }

  const currentPage = requestedPageNumber;
  const from = (currentPage - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

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
    .order("created_at", { ascending: false })
    .order("id", { ascending: false })
    .range(from, to);

  if (error) {
    throw new Error(`Unable to load role assignments: ${error.message}`);
  }

  const assignmentIds = assignments.map((assignment) => assignment.id);
  const { data: events, error: eventsError } = assignmentIds.length
    ? await supabase
        .from("role_assignment_events")
        .select(
          "id, assignment_id, related_assignment_id, actor_user_id, event_type, reason, occurred_at"
        )
        .in("assignment_id", assignmentIds)
        .order("occurred_at", { ascending: false })
    : { data: [], error: null };

  if (eventsError) {
    throw new Error(
      `Unable to load role assignment history: ${eventsError.message}`
    );
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

          <div className="flex flex-wrap items-center gap-3">
            <Link
              href="/platform/access-roles/new"
              className="rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white hover:bg-slate-800"
            >
              Create role assignment
            </Link>

            <Link
              href="/platform"
              className="text-sm font-semibold text-slate-700 hover:text-slate-950"
            >
              Back to dashboard
            </Link>
          </div>
        </section>

        {resolvedSearchParams.created === "1" ? (
          <section className="rounded-xl border border-emerald-200 bg-emerald-50 px-5 py-4">
            <p className="text-sm font-semibold text-emerald-900">
              Role assignment created successfully.
            </p>
          </section>
        ) : null}

        {resolvedSearchParams.revoke === "1" ||
        resolvedSearchParams.expire === "1" ||
        resolvedSearchParams.renew === "1" ? (
          <section className="rounded-xl border border-emerald-200 bg-emerald-50 px-5 py-4">
            <p className="text-sm font-semibold text-emerald-900">
              Role assignment lifecycle updated successfully.
            </p>
          </section>
        ) : null}

        {resolvedSearchParams.lifecycle_error ? (
          <section className="rounded-xl border border-red-200 bg-red-50 px-5 py-4">
            <p className="text-sm font-semibold text-red-900">
              {resolvedSearchParams.lifecycle_error}
            </p>
          </section>
        ) : null}

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
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Lifecycle & History
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

                    const assignmentEvents = events.filter(
                      (event) => event.assignment_id === assignment.id
                    );

                    const isEffectivelyExpired =
                      assignment.status === "active" &&
                      assignment.valid_until !== null &&
                      new Date(assignment.valid_until) <= new Date();

                    const canEnd = assignment.status === "active";
                    const canRenew =
                      assignment.status === "expired" ||
                      assignment.status === "revoked" ||
                      isEffectivelyExpired;

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

                        <td className="min-w-72 px-6 py-4 align-top">
                          <div className="grid gap-2">
                            {canEnd ? (
                              <details className="rounded-lg border border-slate-200 p-2">
                                <summary className="cursor-pointer font-semibold text-slate-700">
                                  End assignment
                                </summary>

                                <div className="mt-3 grid gap-3">
                                  <form action={expireRoleAssignment} className="grid gap-2">
                                    <input type="hidden" name="assignment_id" value={assignment.id} />
                                    <label className="text-xs font-semibold text-slate-600" htmlFor={`expire-reason-${assignment.id}`}>
                                      Expiration reason
                                    </label>
                                    <textarea id={`expire-reason-${assignment.id}`} name="reason" required maxLength={500} className="min-h-16 rounded-lg border border-slate-300 p-2 text-sm" />
                                    <button className="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-900" type="submit">
                                      Expire now
                                    </button>
                                  </form>

                                  <form action={revokeRoleAssignment} className="grid gap-2 border-t border-slate-200 pt-3">
                                    <input type="hidden" name="assignment_id" value={assignment.id} />
                                    <label className="text-xs font-semibold text-slate-600" htmlFor={`revoke-reason-${assignment.id}`}>
                                      Revocation reason
                                    </label>
                                    <textarea id={`revoke-reason-${assignment.id}`} name="reason" required maxLength={500} className="min-h-16 rounded-lg border border-slate-300 p-2 text-sm" />
                                    <button className="rounded-lg border border-red-300 bg-red-50 px-3 py-2 text-xs font-semibold text-red-900" type="submit">
                                      Revoke access
                                    </button>
                                  </form>
                                </div>
                              </details>
                            ) : null}

                            {canRenew ? (
                              <details className="rounded-lg border border-slate-200 p-2">
                                <summary className="cursor-pointer font-semibold text-slate-700">
                                  Renew assignment
                                </summary>
                                <form action={renewRoleAssignment} className="mt-3 grid gap-2">
                                  <input type="hidden" name="assignment_id" value={assignment.id} />
                                  <label className="text-xs font-semibold text-slate-600" htmlFor={`renew-until-${assignment.id}`}>
                                    New expiration date (optional)
                                  </label>
                                  <input id={`renew-until-${assignment.id}`} type="date" name="valid_until" className="rounded-lg border border-slate-300 p-2 text-sm" />
                                  <label className="text-xs font-semibold text-slate-600" htmlFor={`renew-reason-${assignment.id}`}>
                                    Renewal reason
                                  </label>
                                  <textarea id={`renew-reason-${assignment.id}`} name="reason" required maxLength={500} className="min-h-16 rounded-lg border border-slate-300 p-2 text-sm" />
                                  <button className="rounded-lg bg-slate-950 px-3 py-2 text-xs font-semibold text-white" type="submit">
                                    Create renewed assignment
                                  </button>
                                </form>
                              </details>
                            ) : null}

                            <details className="rounded-lg border border-slate-200 p-2">
                              <summary className="cursor-pointer font-semibold text-slate-700">
                                History ({assignmentEvents.length})
                              </summary>
                              {assignmentEvents.length ? (
                                <ol className="mt-3 grid gap-3">
                                  {assignmentEvents.map((event) => (
                                    <li key={event.id} className="border-l-2 border-slate-200 pl-3 text-xs text-slate-600">
                                      <p className="font-semibold capitalize text-slate-800">
                                        {event.event_type}
                                      </p>
                                      <p>{new Date(event.occurred_at).toLocaleString("en-US")}</p>
                                      <p>Actor: {event.actor_user_id ?? "System"}</p>
                                      {event.reason ? <p>Reason: {event.reason}</p> : null}
                                      {event.related_assignment_id ? <p>Renews: {event.related_assignment_id}</p> : null}
                                    </li>
                                  ))}
                                </ol>
                              ) : (
                                <p className="mt-2 text-xs text-slate-500">
                                  No recorded events yet.
                                </p>
                              )}
                            </details>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <section className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-sm text-slate-600">
            Page {currentPage} of {totalPages} · {totalAssignments} role{" "}
            {totalAssignments === 1 ? "assignment" : "assignments"}
          </p>

          <div className="flex items-center gap-2">
            {currentPage > 1 ? (
              <Link
                href={`/platform/access-roles?page=${currentPage - 1}`}
                className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
              >
                Previous
              </Link>
            ) : (
              <span className="cursor-not-allowed rounded-lg border border-slate-200 bg-slate-100 px-4 py-2 text-sm font-semibold text-slate-400">
                Previous
              </span>
            )}

            {currentPage < totalPages ? (
              <Link
                href={`/platform/access-roles?page=${currentPage + 1}`}
                className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
              >
                Next
              </Link>
            ) : (
              <span className="cursor-not-allowed rounded-lg border border-slate-200 bg-slate-100 px-4 py-2 text-sm font-semibold text-slate-400">
                Next
              </span>
            )}
          </div>
        </section>
      </div>
    </AdminShell>
  );
}
