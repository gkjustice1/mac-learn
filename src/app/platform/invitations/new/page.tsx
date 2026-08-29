import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

import { InvitationForm } from "./InvitationForm";

export default async function NewInvitationPage() {
  await requirePlatformAdmin();

  const supabase = await createClient();
  const [organizationsResult, sitesResult] = await Promise.all([
    supabase
      .from("organizations")
      .select("id, name")
      .eq("status", "active")
      .order("name", { ascending: true }),
    supabase
      .from("sites")
      .select("id, name, organization_id")
      .eq("status", "active")
      .order("name", { ascending: true }),
  ]);

  if (organizationsResult.error) {
    throw new Error(
      `Unable to load organizations: ${organizationsResult.error.message}`
    );
  }

  if (sitesResult.error) {
    throw new Error(`Unable to load sites: ${sitesResult.error.message}`);
  }

  const organizations = organizationsResult.data.map((organization) => ({
    id: organization.id,
    name: organization.name,
  }));
  const sites = sitesResult.data.map((site) => ({
    id: site.id,
    name: site.name,
    organizationId: site.organization_id,
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
              Invite user
            </h2>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
              Provision a tenant-scoped enterprise identity and email a secure
              password-creation link.
            </p>
          </div>

          <Link
            href="/platform/access-roles"
            className="text-sm font-semibold text-slate-700 hover:text-slate-950"
          >
            Back to Access &amp; Roles
          </Link>
        </section>

        <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <InvitationForm organizations={organizations} sites={sites} />
        </section>
      </div>
    </AdminShell>
  );
}
