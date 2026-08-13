import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

export default async function PlatformPage() {
  await requirePlatformAdmin();

const supabase = await createClient();

const { count: organizationCount, error: organizationCountError } =
  await supabase
    .from("organizations")
    .select("id", { count: "exact", head: true })
    .eq("status", "active");

if (organizationCountError) {
  throw new Error(
    `Unable to load organization count: ${organizationCountError.message}`
  );
}

const metrics = [
  {
    label: "Organizations",
    value: String(organizationCount ?? 0),
    detail:
      organizationCount === 1
        ? "Active organization"
        : "Active organizations",
  },
  {
    label: "Sites",
    value: "1",
    detail: "Active site",
  },
  {
    label: "Authorization",
    value: "Active",
    detail: "Platform admin access",
  },
];

  return (
    <AdminShell>
      <div className="grid gap-8">
        <section>
          <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
            Platform overview
          </p>

          <div className="mt-2">
            <h2 className="text-3xl font-bold tracking-tight text-slate-950">
              Platform administration
            </h2>

            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              Manage MAC Learn organizations, sites, access, and platform-wide
              operations from one secure workspace.
            </p>
          </div>
        </section>

        <section className="grid gap-4 md:grid-cols-3">
          {metrics.map((metric) => (
            <article
              key={metric.label}
              className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <p className="text-sm font-medium text-slate-500">
                {metric.label}
              </p>

              <p className="mt-2 text-3xl font-bold text-slate-950">
                {metric.value}
              </p>

              <p className="mt-2 text-sm text-slate-600">
                {metric.detail}
              </p>
            </article>
          ))}
        </section>

        <section className="grid gap-4 lg:grid-cols-2">
          <article className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
            <h3 className="text-lg font-semibold text-slate-950">
              Organization management
            </h3>

            <p className="mt-2 text-sm leading-6 text-slate-600">
              View and manage organizations operating within the MAC Learn
              platform.
            </p>
          </article>

          <article className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
            <h3 className="text-lg font-semibold text-slate-950">
              Site management
            </h3>

            <p className="mt-2 text-sm leading-6 text-slate-600">
              Manage campuses, locations, and site-level administration.
            </p>
          </article>
        </section>
      </div>
    </AdminShell>
  );
}