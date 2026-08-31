import { redirect } from "next/navigation";

import { logout } from "@/app/actions";
import { requireRole } from "@/lib/auth/authorization";
import { getAuthorizationContext } from "@/lib/auth/context";
import { createClient } from "@/lib/supabase/server";

function relatedRecord<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

function formatDateTime(value: string, timeZone: string) {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone,
  }).format(new Date(value));
}

function EmptyState({ children }: { children: React.ReactNode }) {
  return (
    <p className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-600">
      {children}
    </p>
  );
}

type FamilySessionSummary = {
  id: string;
  session_id: string;
  student_id: string;
  attendance_status: string;
  parent_summary: string | null;
  created_at: string;
};

type StudentScope = {
  organization_id: string;
  primary_site_id: string | null;
};

type FamilyStudent = StudentScope & {
  id: string;
  first_name: string;
  last_name: string;
  grade_level: string;
  school_name: string | null;
};

export default async function FamilyPage() {
  const context = await getAuthorizationContext();
  const assignment = context.roles.find((role) => role.role === "guardian");

  if (!assignment?.organizationId) redirect("/unauthorized");

  await requireRole("guardian", {
    organizationId: assignment.organizationId,
    siteId: assignment.siteId,
  });

  const supabase = await createClient();
  const guardianAssignments = context.roles.filter(
    (role) => role.role === "guardian" && role.organizationId
  );
  const organizationIds = [
    ...new Set(guardianAssignments.map((role) => role.organizationId as string)),
  ];
  const [organizationResult, configurationsResult, siteResult, scopeSitesResult, studentsResult] =
    await Promise.all([
      supabase.from("organizations").select("name").eq("id", assignment.organizationId).maybeSingle(),
      supabase.from("organization_configurations").select("organization_id, default_timezone").in("organization_id", organizationIds),
      assignment.siteId
        ? supabase.from("sites").select("name, timezone").eq("id", assignment.siteId).maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      supabase.from("sites").select("id, organization_id, timezone").in("organization_id", organizationIds),
      supabase.rpc("mac_family_students"),
    ]);

  const initialFailure = [organizationResult, configurationsResult, siteResult, scopeSitesResult, studentsResult].find((result) => result.error);
  if (initialFailure?.error) throw new Error(`Unable to load Family workspace: ${initialFailure.error.message}`);

  const students = (studentsResult.data ?? []) as FamilyStudent[];
  const studentIds = students.map((student) => student.id);
  const [sessionsResult, upcomingSessionsResult, summariesResult, reportsResult] =
    await Promise.all([
      studentIds.length > 0
        ? supabase.from("sessions").select("id, student_id, start_time, end_time, status, zoom_link, student:students(first_name, last_name, organization_id, primary_site_id), subject:subjects(name)").in("student_id", studentIds).order("start_time", { ascending: true })
        : Promise.resolve({ data: [], error: null }),
      studentIds.length > 0
        ? supabase.from("sessions").select("id", { count: "exact", head: true }).in("student_id", studentIds).in("status", ["pending", "confirmed"]).gte("end_time", "now")
        : Promise.resolve({ data: null, error: null, count: 0 }),
      supabase.rpc("mac_family_session_summaries"),
      studentIds.length > 0
        ? supabase.from("progress_reports").select("id, student_id, reporting_period, strengths, areas_for_improvement, skills_mastered, next_goals, comments, created_at, student:students(first_name, last_name, organization_id, primary_site_id), subject:subjects(name)").in("student_id", studentIds).order("created_at", { ascending: false })
        : Promise.resolve({ data: [], error: null }),
    ]);
  const scopedFailure = [sessionsResult, upcomingSessionsResult, summariesResult, reportsResult].find((result) => result.error);
  if (scopedFailure?.error) throw new Error(`Unable to load Family workspace: ${scopedFailure.error.message}`);

  const sessions = sessionsResult.data ?? [];
  const summaries = (summariesResult.data ?? []) as FamilySessionSummary[];
  const reports = reportsResult.data ?? [];
  const organizationTimeZones = new Map(
    (configurationsResult.data ?? []).map((configuration) => [
      configuration.organization_id,
      configuration.default_timezone,
    ])
  );
  const siteTimeZones = new Map(
    (scopeSitesResult.data ?? []).map((site) => [site.id, site.timezone])
  );
  const timeZoneForStudent = (student: StudentScope | null) =>
    (student?.primary_site_id
      ? siteTimeZones.get(student.primary_site_id)
      : undefined) ??
    (student?.organization_id
      ? organizationTimeZones.get(student.organization_id)
      : undefined) ??
    "UTC";
  const studentNames = new Map(students.map((student) => [student.id, `${student.first_name} ${student.last_name}`]));
  const studentTimeZones = new Map(
    students.map((student) => [student.id, timeZoneForStudent(student)])
  );

  return (
    <main className="min-h-screen bg-slate-50 text-slate-950">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-6 py-5">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-lime-700">MAC Learn</p>
            <p className="mt-1 text-lg font-bold">Family workspace</p>
          </div>
          <div className="flex items-center gap-3">
            <span className="rounded-full bg-lime-100 px-3 py-1 text-sm font-semibold text-lime-800">Family</span>
            <form action={logout}><button type="submit" className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold hover:bg-slate-50">Sign out</button></form>
          </div>
        </div>
      </header>

      <div className="mx-auto grid max-w-7xl gap-8 px-6 py-8">
        <section className="grid gap-4 lg:grid-cols-[1fr_auto] lg:items-end">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
              {organizationResult.data?.name ?? "Assigned organization"}{siteResult.data?.name ? ` · ${siteResult.data.name}` : ""}
            </p>
            <h1 className="mt-2 text-3xl font-bold tracking-tight">Welcome, {context.user.user_metadata?.first_name ?? "Family"}</h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">Review linked students, sessions, attendance summaries, progress, and upcoming learning goals.</p>
          </div>
          <nav aria-label="Family workspace sections" className="flex flex-wrap gap-2">
            {["Students", "Sessions", "Summaries", "Progress"].map((label) => <a key={label} href={`#${label.toLowerCase()}`} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold hover:border-slate-400">{label}</a>)}
          </nav>
        </section>

        <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[
            { label: "Linked students", value: students.length },
            { label: "Upcoming sessions", value: upcomingSessionsResult.count ?? 0 },
            { label: "Session summaries", value: summaries.length },
            { label: "Progress reports", value: reports.length },
          ].map((metric) => <article key={metric.label} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm font-medium text-slate-500">{metric.label}</p><p className="mt-2 text-3xl font-bold">{metric.value}</p></article>)}
        </section>

        <section id="students" className="scroll-mt-6">
          <h2 className="text-xl font-bold">Linked students</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {students.length === 0 ? <EmptyState>No students are linked to this Family account.</EmptyState> : students.map((student) => <article key={student.id} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><h3 className="font-semibold">{student.first_name} {student.last_name}</h3><p className="mt-2 text-sm text-slate-600">Grade {student.grade_level}{student.school_name ? ` · ${student.school_name}` : ""}</p></article>)}
          </div>
        </section>

        <section id="sessions" className="scroll-mt-6">
          <h2 className="text-xl font-bold">Scheduled sessions</h2>
          <div className="mt-4 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
            {sessions.length === 0 ? <div className="p-5"><EmptyState>No sessions are scheduled.</EmptyState></div> : <div className="overflow-x-auto"><table className="w-full border-collapse text-left text-sm"><thead className="bg-slate-100 text-slate-600"><tr>{["Student", "Subject", "Starts", "Status", "Meeting"].map((heading) => <th key={heading} className="px-4 py-3 font-semibold">{heading}</th>)}</tr></thead><tbody className="divide-y divide-slate-200">{sessions.map((session) => { const student = relatedRecord(session.student); const subject = relatedRecord(session.subject); return <tr key={session.id}><td className="px-4 py-4 font-medium">{student?.first_name} {student?.last_name}</td><td className="px-4 py-4">{subject?.name ?? "General tutoring"}</td><td className="px-4 py-4">{formatDateTime(session.start_time, timeZoneForStudent(student))}</td><td className="px-4 py-4 capitalize">{(session.status ?? "unspecified").replaceAll("_", " ")}</td><td className="px-4 py-4">{session.zoom_link ? <a href={session.zoom_link} className="font-semibold text-lime-700 underline">Join</a> : "Not added"}</td></tr>; })}</tbody></table></div>}
          </div>
        </section>

        <section id="summaries" className="scroll-mt-6">
          <h2 className="text-xl font-bold">Attendance and session summaries</h2>
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            {summaries.length === 0 ? <EmptyState>No parent-facing session summaries are available.</EmptyState> : summaries.map((summary) => <article key={summary.id} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><div className="flex items-center justify-between gap-3"><h3 className="font-semibold">{studentNames.get(summary.student_id) ?? "Linked student"}</h3><span className="text-xs text-slate-500">{formatDateTime(summary.created_at, studentTimeZones.get(summary.student_id) ?? "UTC")}</span></div><p className="mt-2 text-sm font-medium capitalize text-slate-600">Attendance: {summary.attendance_status}</p><p className="mt-3 text-sm leading-6 text-slate-700">{summary.parent_summary ?? "No parent summary was added for this session."}</p></article>)}
          </div>
        </section>

        <section id="progress" className="scroll-mt-6 pb-8">
          <h2 className="text-xl font-bold">Progress and upcoming goals</h2>
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            {reports.length === 0 ? <EmptyState>No progress reports are available.</EmptyState> : reports.map((report) => { const student = relatedRecord(report.student); const subject = relatedRecord(report.subject); return <article key={report.id} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><h3 className="font-semibold">{student?.first_name} {student?.last_name}</h3><p className="mt-1 text-sm font-medium text-slate-500">{report.reporting_period}{subject?.name ? ` · ${subject.name}` : ""}</p><dl className="mt-4 grid gap-3 text-sm">{[["Strengths", report.strengths], ["Areas for improvement", report.areas_for_improvement], ["Skills mastered", report.skills_mastered], ["Upcoming goals", report.next_goals], ["Tutor comments", report.comments]].map(([label, value]) => <div key={label}><dt className="font-semibold">{label}</dt><dd className="mt-1 text-slate-600">{value ?? "Not recorded"}</dd></div>)}</dl></article>; })}
          </div>
        </section>
      </div>
    </main>
  );
}
