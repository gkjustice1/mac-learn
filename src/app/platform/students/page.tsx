import Link from "next/link";

import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

export default async function StudentsPage() {
  await requirePlatformAdmin();
  const supabase = await createClient();
  const [studentsResult, eventsResult] = await Promise.all([
    supabase
      .from("students")
      .select("id, first_name, last_name, grade_level, school_name, enterprise_status, enrollment_start_date, organization:organizations(name), site:sites(name)")
      .order("created_at", { ascending: false })
      .limit(100),
    supabase
      .from("student_enrollment_events")
      .select("id, event_type, created_at, details, student:students(first_name, last_name)")
      .order("created_at", { ascending: false })
      .limit(20),
  ]);
  const error = studentsResult.error ?? eventsResult.error;
  if (error) throw new Error(`Unable to load students: ${error.message}`);
  const data = studentsResult.data ?? [];
  const events = eventsResult.data ?? [];

  return (
    <AdminShell activeItem="students">
      <div className="grid gap-6">
        <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div><p className="text-sm font-semibold uppercase tracking-widest text-slate-500">Platform administration</p><h2 className="mt-2 text-3xl font-bold">Students</h2><p className="mt-2 text-sm text-slate-600">Review active and inactive enterprise enrollments.</p></div>
          <Link href="/platform/students/new" className="rounded-xl bg-lime-600 px-5 py-3 text-sm font-semibold text-white">Add student</Link>
        </header>
        <section className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          <table className="min-w-full text-left text-sm"><thead className="bg-slate-50 text-slate-600"><tr>{["Student", "Grade", "School", "Organization", "Site", "Status", "Start date", "Login"].map((heading) => <th key={heading} className="px-5 py-4 font-semibold">{heading}</th>)}</tr></thead>
            <tbody className="divide-y divide-slate-200">{(data ?? []).map((student) => {
              const organization = Array.isArray(student.organization) ? student.organization[0] : student.organization;
              const site = Array.isArray(student.site) ? student.site[0] : student.site;
              return <tr key={student.id}><td className="px-5 py-4 font-semibold">{student.first_name} {student.last_name}</td><td className="px-5 py-4">{student.grade_level}</td><td className="px-5 py-4">{student.school_name ?? "—"}</td><td className="px-5 py-4">{organization?.name ?? "—"}</td><td className="px-5 py-4">{site?.name ?? "—"}</td><td className="px-5 py-4 capitalize">{student.enterprise_status ?? "active"}</td><td className="px-5 py-4">{student.enrollment_start_date ?? "—"}</td><td className="px-5 py-4"><Link href={`/platform/students/${student.id}/invite`} className="font-semibold underline">Invite login</Link></td></tr>;
            })}</tbody></table>
          {(data ?? []).length === 0 ? <p className="p-8 text-sm text-slate-600">No students have been enrolled yet.</p> : null}
        </section>
        <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <h3 className="text-lg font-bold">Recent enrollment history</h3>
          <div className="mt-4 grid gap-3">
            {events.map((event) => {
              const student = Array.isArray(event.student) ? event.student[0] : event.student;
              return <div key={event.id} className="rounded-xl border border-slate-200 px-4 py-3 text-sm"><span className="font-semibold">{student?.first_name} {student?.last_name}</span><span className="mx-2 text-slate-400">•</span><span className="capitalize">{event.event_type}</span><span className="mx-2 text-slate-400">•</span><time dateTime={event.created_at}>{new Date(event.created_at).toLocaleString()}</time></div>;
            })}
            {events.length === 0 ? <p className="text-sm text-slate-600">No enrollment events recorded yet.</p> : null}
          </div>
        </section>
      </div>
    </AdminShell>
  );
}
