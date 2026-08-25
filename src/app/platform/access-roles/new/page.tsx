import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";

import { RoleAssignmentForm } from "./RoleAssignmentForm";

export default async function NewPlatformRoleAssignmentPage() {
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
              Create Role Assignment
            </h2>

            <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
              Assign an active MAC Learn user an active role and
              authorization scope. Only active organizations and sites
              may receive new assignments. Database constraints and Row
              Level Security remain authoritative.
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
          <RoleAssignmentForm />
        </section>
      </div>
    </AdminShell>
  );
}
