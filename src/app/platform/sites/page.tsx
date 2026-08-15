import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

export default async function PlatformSitesPage() {
  await requirePlatformAdmin();

  const supabase = await createClient();

  const { data: sites, error } = await supabase
    .from("sites")
    .select(
      `
        id,
        name,
        code,
        status,
        city,
        state_region,
        created_at,
        organization:organizations (
          id,
          name
        )
      `
    )
    .order("name", { ascending: true });

  if (error) {
    throw new Error(`Unable to load sites: ${error.message}`);
  }

  return (
    <AdminShell activeItem="sites">
      <div className="grid gap-8">
        <section className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
              Platform administration
            </p>

            <h2 className="mt-2 text-3xl font-bold tracking-tight text-slate-950">
              Sites
            </h2>

            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              View campuses, centers, branches, and other operating locations
              configured in MAC Learn.
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
          {sites.length === 0 ? (
            <div className="p-6 text-sm text-slate-600">
              No sites are currently configured.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-sm">
                <thead className="border-b border-slate-200 bg-slate-50">
                  <tr>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Site
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Organization
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Code
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Location
                    </th>
                    <th className="px-6 py-4 font-semibold text-slate-700">
                      Status
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-slate-200">
                  {sites.map((site) => {
                    const organization = Array.isArray(site.organization)
                      ? site.organization[0]
                      : site.organization;

                    const location =
                      [site.city, site.state_region]
                        .filter(Boolean)
                        .join(", ") || "Not specified";

                    return (
                      <tr key={site.id}>
                        <td className="px-6 py-4">
                          {organization?.id ? (
                            <Link
                              href={`/organizations/${organization.id}/sites/${site.id}`}
                              className="font-semibold text-slate-950 hover:underline"
                            >
                              {site.name}
                            </Link>
                          ) : (
                            <span className="font-semibold text-slate-950">
                              {site.name}
                            </span>
                          )}
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {organization?.name ?? "Unknown organization"}
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {site.code ?? "—"}
                        </td>

                        <td className="px-6 py-4 text-slate-600">
                          {location}
                        </td>

                        <td className="px-6 py-4">
                          <span className="inline-flex rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold capitalize text-slate-700">
                            {site.status}
                          </span>
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