import Link from "next/link";
import { notFound } from "next/navigation";

import { OrganizationConfigurationForm } from "./OrganizationConfigurationForm";
import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

type OrganizationConfigurationPageProps = {
  params: Promise<{ organizationId: string }>;
};

export default async function OrganizationConfigurationPage({
  params,
}: OrganizationConfigurationPageProps) {
  await requirePlatformAdmin();

  const { organizationId } = await params;
  const supabase = await createClient();

  const [{ data: organization, error: organizationError }, { data: configuration, error: configurationError }] =
    await Promise.all([
      supabase
        .from("organizations")
        .select("id, name, slug")
        .eq("id", organizationId)
        .maybeSingle(),
      supabase
        .from("organization_configurations")
        .select(
          "default_timezone, default_locale, supported_locales, academic_year_start_month, attendance_required"
        )
        .eq("organization_id", organizationId)
        .maybeSingle(),
    ]);

  if (organizationError || configurationError) {
    throw new Error(
      `Unable to load organization configuration: ${(organizationError ?? configurationError)?.message}`
    );
  }

  if (!organization || !configuration) {
    notFound();
  }

  return (
    <AdminShell activeItem="organizations">
      <div className="grid max-w-3xl gap-8">
        <section className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
              Tenant configuration
            </p>
            <h2 className="mt-2 text-3xl font-bold tracking-tight text-slate-950">
              {organization.name}
            </h2>
            <p className="mt-2 text-sm leading-6 text-slate-600">
              Set the defaults used as MAC Learn expands this organization.
            </p>
          </div>
          <Link
            href="/platform/organizations"
            className="text-sm font-semibold text-slate-700 hover:text-slate-950"
          >
            Back to organizations
          </Link>
        </section>

        <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <OrganizationConfigurationForm
            organizationId={organization.id}
            defaultTimezone={configuration.default_timezone}
            defaultLocale={configuration.default_locale}
            supportedLocales={configuration.supported_locales}
            academicYearStartMonth={configuration.academic_year_start_month}
            attendanceRequired={configuration.attendance_required}
          />
        </section>
      </div>
    </AdminShell>
  );
}
