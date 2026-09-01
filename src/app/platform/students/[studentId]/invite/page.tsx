import Link from "next/link";
import { notFound } from "next/navigation";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

import { StudentLoginInvitationForm } from "./StudentLoginInvitationForm";

export default async function InviteStudentLoginPage({ params }: { params: Promise<{ studentId: string }> }) {
  await requirePlatformAdmin();
  const { studentId } = await params;
  const supabase = await createClient();
  const { data: student, error } = await supabase.from("students").select("id, first_name, last_name, grade_level, enterprise_status, person_id, organization:organizations(name), site:sites(name)").eq("id", studentId).maybeSingle();
  if (error) throw new Error(`Unable to load student: ${error.message}`);
  if (!student) notFound();
  const organization = Array.isArray(student.organization) ? student.organization[0] : student.organization;
  const site = Array.isArray(student.site) ? student.site[0] : student.site;
  const eligible = student.enterprise_status === "active" && Boolean(student.person_id && site);
  return <AdminShell activeItem="students"><div className="grid gap-8">
    <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"><div><p className="text-sm font-semibold uppercase tracking-widest text-slate-500">Platform administration</p><h2 className="mt-2 text-3xl font-bold">Invite Student login</h2><p className="mt-2 text-sm text-slate-600">Link a secure login to an existing canonical enrollment.</p></div><Link href="/platform/students" className="text-sm font-semibold">Back to Students</Link></header>
    <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"><div className="mb-6 grid gap-1 rounded-xl bg-slate-50 p-4"><strong>{student.first_name} {student.last_name}</strong><span className="text-sm text-slate-600">{student.grade_level} · {organization?.name ?? "No organization"} · {site?.name ?? "No primary site"}</span></div>{eligible ? <StudentLoginInvitationForm studentId={student.id} /> : <p role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-semibold text-red-900">This student needs an active enrollment, canonical person, and active primary site before a login can be invited.</p>}</section>
  </div></AdminShell>;
}
