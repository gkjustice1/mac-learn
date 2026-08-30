import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";

import { StudentEnrollmentForm } from "./StudentEnrollmentForm";

export default async function NewStudentPage() {
  await requirePlatformAdmin();
  return (
    <AdminShell activeItem="students">
      <div className="grid gap-8">
        <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div><p className="text-sm font-semibold uppercase tracking-widest text-slate-500">Platform administration</p><h2 className="mt-2 text-3xl font-bold">Add student</h2><p className="mt-2 text-sm text-slate-600">Create a tenant-scoped enrollment and verified family relationship.</p></div>
          <Link href="/platform/students" className="text-sm font-semibold">Back to Students</Link>
        </header>
        <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"><StudentEnrollmentForm /></section>
      </div>
    </AdminShell>
  );
}
