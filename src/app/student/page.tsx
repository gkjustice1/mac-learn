import { redirect } from "next/navigation";

import { logout } from "@/app/actions";
import { requireRole } from "@/lib/auth/authorization";
import { getAuthorizationContext } from "@/lib/auth/context";
import { createClient } from "@/lib/supabase/server";

function relatedRecord<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

function EmptyState({ children }: { children: React.ReactNode }) {
  return <p className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-600">{children}</p>;
}

function formatDateTime(value: string, timeZone: string) {
  return new Intl.DateTimeFormat("en-US", { dateStyle: "medium", timeStyle: "short", timeZone }).format(new Date(value));
}

type StudentFeedback = {
  id: string;
  attendance_status: string;
  skills_covered: string | null;
  performance_notes: string | null;
  homework_assigned: string | null;
};

export default async function StudentPage() {
  const context = await getAuthorizationContext();
  const assignment = context.roles.find((role) => role.role === "student");
  if (!assignment?.organizationId) redirect("/unauthorized");
  await requireRole("student", { organizationId: assignment.organizationId, siteId: assignment.siteId });

  const supabase = await createClient();
  const studentsResult = await supabase.rpc("mac_current_student_ids");
  if (studentsResult.error) throw new Error(`Unable to load Student workspace: ${studentsResult.error.message}`);
  const studentIds = (studentsResult.data ?? []) as string[];
  const studentsResult2 = studentIds.length
    ? await supabase.from("students").select("id, first_name, last_name, grade_level, school_name, organization_id, primary_site_id").in("id", studentIds)
    : { data: [], error: null };
  if (studentsResult2.error) throw new Error(`Unable to load Student workspace: ${studentsResult2.error.message}`);
  const students = studentsResult2.data ?? [];
  const organizationIds = [...new Set(students.map((student) => student.organization_id))];
  const [sessionsResult, assignmentsResult, contentResult, feedbackResult, progressResult, configurationsResult, sitesResult] = await Promise.all([
    studentIds.length ? supabase.from("sessions").select("id, student_id, start_time, end_time, status, zoom_link, subject:subjects(name)").in("student_id", studentIds).order("start_time", { ascending: true }) : Promise.resolve({ data: [], error: null }),
    studentIds.length ? supabase.from("homework_uploads").select("id, student_id, file_name, file_url, notes, created_at, subject:subjects(name)").in("student_id", studentIds).order("created_at", { ascending: false }) : Promise.resolve({ data: [], error: null }),
    studentIds.length ? supabase.from("educator_instructional_records").select("id, student_id, record_type, content, occurred_on").in("student_id", studentIds).order("occurred_on", { ascending: false }) : Promise.resolve({ data: [], error: null }),
    supabase.rpc("mac_student_feedback"),
    studentIds.length ? supabase.from("progress_reports").select("id, student_id, reporting_period, strengths, areas_for_improvement, skills_mastered, next_goals, comments, created_at, subject:subjects(name)").in("student_id", studentIds).order("created_at", { ascending: false }) : Promise.resolve({ data: [], error: null }),
    organizationIds.length ? supabase.from("organization_configurations").select("organization_id, default_timezone").in("organization_id", organizationIds) : Promise.resolve({ data: [], error: null }),
    organizationIds.length ? supabase.from("sites").select("id, organization_id, timezone").in("organization_id", organizationIds) : Promise.resolve({ data: [], error: null }),
  ]);
  const failure = [sessionsResult, assignmentsResult, contentResult, feedbackResult, progressResult, configurationsResult, sitesResult].find((result) => result.error);
  if (failure?.error) throw new Error(`Unable to load Student workspace: ${failure.error.message}`);
  const sessions = sessionsResult.data ?? [];
  const assignments = assignmentsResult.data ?? [];
  const content = contentResult.data ?? [];
  const feedback = (feedbackResult.data ?? []) as StudentFeedback[];
  const progress = progressResult.data ?? [];
  const firstStudent = students[0];
  const organizationTimeZones = new Map((configurationsResult.data ?? []).map((configuration) => [configuration.organization_id, configuration.default_timezone]));
  const siteTimeZones = new Map((sitesResult.data ?? []).map((site) => [site.id, site.timezone]));
  const studentScopes = new Map(students.map((student) => [student.id, student]));
  const timeZoneForStudent = (studentId: string) => {
    const student = studentScopes.get(studentId);
    return (student?.primary_site_id ? siteTimeZones.get(student.primary_site_id) : undefined) ?? (student?.organization_id ? organizationTimeZones.get(student.organization_id) : undefined) ?? "UTC";
  };

  return <main className="min-h-screen bg-slate-50 text-slate-950">
    <header className="border-b border-slate-200 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5"><div><p className="text-xs font-bold uppercase tracking-[0.2em] text-lime-700">MAC Learn</p><p className="mt-1 text-lg font-bold">Student workspace</p></div><div className="flex items-center gap-3"><span className="rounded-full bg-lime-100 px-3 py-1 text-sm font-semibold text-lime-800">Student</span><form action={logout}><button className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold">Sign out</button></form></div></div></header>
    <div className="mx-auto grid max-w-7xl gap-8 px-6 py-8">
      <section><p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">Your learning space</p><h1 className="mt-2 text-3xl font-bold">Welcome, {firstStudent?.first_name ?? "Student"}</h1><p className="mt-2 text-sm text-slate-600">View your sessions, assignments, learning content, Tutor feedback, and progress.</p><nav className="mt-5 flex flex-wrap gap-2">{["Sessions", "Assignments", "Learning content", "Tutor feedback", "Progress"].map((label) => <a key={label} href={`#${label.toLowerCase().replace(" ", "-")}`} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold">{label}</a>)}</nav></section>
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">{[["Enrollments", students.length], ["Sessions", sessions.length], ["Assignments", assignments.length], ["Feedback", feedback.length], ["Progress reports", progress.length]].map(([label, value]) => <article key={String(label)} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm text-slate-500">{label}</p><p className="mt-2 text-3xl font-bold">{value}</p></article>)}</section>
      <section id="sessions"><h2 className="text-xl font-bold">Sessions</h2><div className="mt-4 grid gap-3">{sessions.length ? sessions.map((session) => { const subject = relatedRecord(session.subject); return <article key={session.id} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="font-semibold">{subject?.name ?? "General tutoring"}</p><p className="mt-2 text-sm text-slate-600">{formatDateTime(session.start_time, timeZoneForStudent(session.student_id))} · <span className="capitalize">{session.status?.replaceAll("_", " ")}</span></p>{session.zoom_link ? <a href={session.zoom_link} className="mt-3 inline-block font-semibold text-lime-700 underline">Join session</a> : null}</article>; }) : <EmptyState>No sessions are scheduled.</EmptyState>}</div></section>
      <section id="assignments"><h2 className="text-xl font-bold">Assignments</h2><div className="mt-4 grid gap-3">{assignments.length ? assignments.map((item) => <article key={item.id} className="rounded-2xl border border-slate-200 bg-white p-5"><a href={item.file_url} className="font-semibold text-lime-700 underline">{item.file_name}</a><p className="mt-2 text-sm text-slate-600">{item.notes ?? "No instructions added."}</p></article>) : <EmptyState>No file assignments are available.</EmptyState>}</div></section>
      <section id="learning-content"><h2 className="text-xl font-bold">Learning content</h2><div className="mt-4 grid gap-3">{content.length ? content.map((item) => <article key={item.id} className="rounded-2xl border border-slate-200 bg-white p-5"><p className="text-sm font-semibold capitalize text-slate-500">{item.record_type.replaceAll("_", " ")}</p><p className="mt-2 text-sm leading-6">{item.content}</p></article>) : <EmptyState>No learning content has been shared yet.</EmptyState>}</div></section>
      <section id="tutor-feedback"><h2 className="text-xl font-bold">Tutor feedback</h2><div className="mt-4 grid gap-3">{feedback.length ? feedback.map((item) => <article key={item.id} className="rounded-2xl border border-slate-200 bg-white p-5"><p className="font-semibold capitalize">Attendance: {item.attendance_status}</p><dl className="mt-3 grid gap-2 text-sm">{[["Skills covered", item.skills_covered], ["Performance feedback", item.performance_notes], ["Homework", item.homework_assigned]].map(([label, value]) => <div key={label}><dt className="font-semibold">{label}</dt><dd className="text-slate-600">{value ?? "Not recorded"}</dd></div>)}</dl></article>) : <EmptyState>No Tutor feedback is available.</EmptyState>}</div></section>
      <section id="progress" className="pb-8"><h2 className="text-xl font-bold">Progress</h2><div className="mt-4 grid gap-3">{progress.length ? progress.map((report) => <article key={report.id} className="rounded-2xl border border-slate-200 bg-white p-5"><p className="font-semibold">{report.reporting_period}</p><dl className="mt-3 grid gap-2 text-sm">{[["Strengths", report.strengths], ["Areas for improvement", report.areas_for_improvement], ["Skills mastered", report.skills_mastered], ["Next goals", report.next_goals], ["Tutor comments", report.comments]].map(([label, value]) => <div key={label}><dt className="font-semibold">{label}</dt><dd className="text-slate-600">{value ?? "Not recorded"}</dd></div>)}</dl></article>) : <EmptyState>No progress reports are available.</EmptyState>}</div></section>
    </div>
  </main>;
}
