import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

export default async function PlatformOrganizationsPage() {
  await requirePlatformAdmin();

  const supabase = await createClient();

  const { data: organizations, error } = await supabase
    .from("organizations")
    .select("id, name, slug, status, created_at")
    .order("name", { ascending: true });

  if (error) {
    throw new Error(`Unable to load organizations: ${error.message}`);
  }

  return (
    <AdminShell activeItem="organizations">
      <div className="grid gap-8">
        <section className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
              Platform administration
            </p>

            <h2 className="mt-2 text-3xl font-bold tracking-tight text-slate-950">
              Organizations
            </h2>

            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              View the organizations configured in MAC Learn.
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
          {organizations.length === 0 ? (
            <div className="p-6 text-sm text-slate-600">
              No organizations are currently configured.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead className="border-b border-slate-200 bg-slate-50">
                  <tr>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Organization
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Slug
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Status
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Created
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-slate-200">
                  {organizations.map((organization) => (
                    <tr key={organization.id}>
                      <td className="px-6 py-4">
                        <Link
                          href={`/organizations/${organization.id}`}
                          className="font-semibold text-slate-950 hover:underline"
                        >
                          {organization.name}
                        </Link>
                      </td>

                      <td className="px-6 py-4 text-slate-600">
                        {organization.slug}
                      </td>

                      <td className="px-6 py-4">
                        <span className="inline-flex rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold capitalize text-slate-700">
                          {organization.status}
                        </span>
                      </td>

                      <td className="px-6 py-4 text-slate-600">
                        {new Date(organization.created_at).toLocaleDateString(
                          "en-US",
                          {
                            year: "numeric",
                            month: "short",
                            day: "numeric",
                          }
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </AdminShell>
  );
}