import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";

import { InvitationForm } from "./InvitationForm";

export default async function NewInvitationPage() {
  await requirePlatformAdmin();

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
          <InvitationForm />
        </section>
      </div>
    </AdminShell>
  );
}
