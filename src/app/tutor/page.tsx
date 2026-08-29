import { redirect } from "next/navigation";

import { logout } from "@/app/actions";
import { requireRole } from "@/lib/auth/authorization";
import { getAuthorizationContext } from "@/lib/auth/context";
import { createClient } from "@/lib/supabase/server";

const DAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
] as const;

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "America/New_York",
  }).format(new Date(value));
}

function formatTime(value: string) {
  const [hour = "0", minute = "00"] = value.split(":");
  return new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
    timeZone: "UTC",
  }).format(new Date(Date.UTC(2000, 0, 1, Number(hour), Number(minute))));
}

function EmptyState({ children }: { children: React.ReactNode }) {
  return (
    <p className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-600">
      {children}
    </p>
  );
}

export default async function TutorPage() {
  const context = await getAuthorizationContext();
  const assignment = context.roles.find((role) => role.role === "tutor");

  if (!assignment || !assignment.organizationId) {
    redirect("/unauthorized");
  }

  await requireRole("tutor", {
    organizationId: assignment.organizationId,
    siteId: assignment.siteId,
  });

  const supabase = await createClient();
  const { data: tutorId, error: tutorIdError } = await supabase.rpc(
    "mac_current_tutor_id"
  );

  if (tutorIdError) {
    throw new Error(`Unable to load tutor identity: ${tutorIdError.message}`);
  }

  const [
    organizationResult,
    siteResult,
    studentsResult,
    sessionsResult,
    availabilityResult,
    notesResult,
    reportsResult,
  ] = await Promise.all([
    supabase
      .from("organizations")
      .select("name")
      .eq("id", assignment.organizationId)
      .maybeSingle(),
    assignment.siteId
      ? supabase
          .from("sites")
          .select("name")
          .eq("id", assignment.siteId)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    supabase
      .from("students")
      .select("id, first_name, last_name, grade_level, school_name")
      .order("last_name")
      .order("first_name"),
    supabase
      .from("sessions")
      .select(
        "id, student_id, start_time, end_time, status, zoom_link, student:students(first_name, last_name), subject:subjects(name)"
      )
      .order("start_time", { ascending: true }),
    supabase
      .from("tutor_availability")
      .select("id, day_of_week, start_time, end_time")
      .order("day_of_week")
      .order("start_time"),
    supabase
      .from("session_notes")
      .select(
        "id, session_id, attendance_status, skills_covered, performance_notes, homework_assigned, parent_summary, created_at"
      )
      .order("created_at", { ascending: false }),
    supabase
      .from("progress_reports")
      .select(
        "id, student_id, reporting_period, strengths, areas_for_improvement, skills_mastered, next_goals, comments, created_at, student:students(first_name, last_name)"
      )
      .order("created_at", { ascending: false }),
  ]);

  const failedResult = [
    organizationResult,
    siteResult,
    studentsResult,
    sessionsResult,
    availabilityResult,
    notesResult,
    reportsResult,
  ].find((result) => result.error);

  if (failedResult?.error) {
    throw new Error(`Unable to load Tutor workspace: ${failedResult.error.message}`);
  }

  const students = studentsResult.data ?? [];
  const sessions = sessionsResult.data ?? [];
  const availability = availabilityResult.data ?? [];
  const notes = notesResult.data ?? [];
  const reports = reportsResult.data ?? [];
  const upcomingSessions = sessions.filter((session) =>
    ["pending", "confirmed"].includes(session.status)
  );

  return (
    <main className="min-h-screen bg-slate-50 text-slate-950">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-6 py-5">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-lime-700">
              MAC Learn
            </p>
            <p className="mt-1 text-lg font-bold">Tutor workspace</p>
          </div>
          <div className="flex items-center gap-3">
            <span className="rounded-full bg-lime-100 px-3 py-1 text-sm font-semibold text-lime-800">
              Tutor
            </span>
            <form action={logout}>
              <button
                type="submit"
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold hover:bg-slate-50"
              >
                Sign out
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="mx-auto grid max-w-7xl gap-8 px-6 py-8">
        <section className="grid gap-4 lg:grid-cols-[1fr_auto] lg:items-end">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">
              {organizationResult.data?.name ?? "Assigned organization"}
              {siteResult.data?.name ? ` · ${siteResult.data.name}` : ""}
            </p>
            <h1 className="mt-2 text-3xl font-bold tracking-tight">
              Welcome back, {context.user.user_metadata?.first_name ?? "Tutor"}
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              Review your assigned learners, upcoming sessions, availability,
              session notes, and progress reporting from one secure workspace.
            </p>
          </div>
          <nav aria-label="Tutor workspace sections" className="flex flex-wrap gap-2">
            {["Students", "Sessions", "Availability", "Notes", "Progress"].map(
              (label) => (
                <a
                  key={label}
                  href={`#${label.toLowerCase()}`}
                  className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold hover:border-slate-400"
                >
                  {label}
                </a>
              )
            )}
          </nav>
        </section>

        {!tutorId && (
          <section
            role="status"
            className="rounded-2xl border border-amber-300 bg-amber-50 p-5"
          >
            <h2 className="font-semibold text-amber-950">
              Tutor profile setup is incomplete
            </h2>
            <p className="mt-1 text-sm leading-6 text-amber-900">
              Your Tutor role is active, but no tutor profile is linked yet.
              Ask a MAC Learn administrator to confirm your profile assignment.
            </p>
          </section>
        )}

        <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[
            { label: "Assigned students", value: students.length },
            { label: "Upcoming sessions", value: upcomingSessions.length },
            { label: "Availability windows", value: availability.length },
            { label: "Progress reports", value: reports.length },
          ].map((metric) => (
            <article
              key={metric.label}
              className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <p className="text-sm font-medium text-slate-500">{metric.label}</p>
              <p className="mt-2 text-3xl font-bold">{metric.value}</p>
            </article>
          ))}
        </section>

        <section id="students" className="scroll-mt-6">
          <h2 className="text-xl font-bold">Assigned students</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {students.length === 0 ? (
              <EmptyState>No students are assigned through a session yet.</EmptyState>
            ) : (
              students.map((student) => (
                <article
                  key={student.id}
                  className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
                >
                  <h3 className="font-semibold">
                    {student.first_name} {student.last_name}
                  </h3>
                  <p className="mt-2 text-sm text-slate-600">
                    Grade {student.grade_level}
                    {student.school_name ? ` · ${student.school_name}` : ""}
                  </p>
                </article>
              ))
            )}
          </div>
        </section>

        <section id="sessions" className="scroll-mt-6">
          <h2 className="text-xl font-bold">Sessions</h2>
          <div className="mt-4 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
            {sessions.length === 0 ? (
              <div className="p-5">
                <EmptyState>No sessions have been assigned.</EmptyState>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-left text-sm">
                  <thead className="bg-slate-100 text-slate-600">
                    <tr>
                      {["Student", "Subject", "Starts", "Status", "Meeting"].map(
                        (heading) => (
                          <th key={heading} className="px-4 py-3 font-semibold">
                            {heading}
                          </th>
                        )
                      )}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200">
                    {sessions.map((session) => {
                      const student = Array.isArray(session.student)
                        ? session.student[0]
                        : session.student;
                      const subject = Array.isArray(session.subject)
                        ? session.subject[0]
                        : session.subject;

                      return (
                      <tr key={session.id}>
                        <td className="px-4 py-4 font-medium">
                          {student?.first_name} {student?.last_name}
                        </td>
                        <td className="px-4 py-4">
                          {subject?.name ?? "General tutoring"}
                        </td>
                        <td className="px-4 py-4">{formatDateTime(session.start_time)}</td>
                        <td className="px-4 py-4 capitalize">
                          {session.status.replaceAll("_", " ")}
                        </td>
                        <td className="px-4 py-4">
                          {session.zoom_link ? (
                            <a
                              href={session.zoom_link}
                              className="font-semibold text-lime-700 underline"
                            >
                              Join
                            </a>
                          ) : (
                            "Not added"
                          )}
                        </td>
                      </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </section>

        <section id="availability" className="scroll-mt-6">
          <h2 className="text-xl font-bold">Availability</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {availability.length === 0 ? (
              <EmptyState>No availability windows have been added.</EmptyState>
            ) : (
              availability.map((window) => (
                <article
                  key={window.id}
                  className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
                >
                  <h3 className="font-semibold">{DAYS[window.day_of_week]}</h3>
                  <p className="mt-2 text-sm text-slate-600">
                    {formatTime(window.start_time)}–{formatTime(window.end_time)}
                  </p>
                </article>
              ))
            )}
          </div>
        </section>

        <section id="notes" className="scroll-mt-6">
          <h2 className="text-xl font-bold">Session notes</h2>
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            {notes.length === 0 ? (
              <EmptyState>No session notes have been recorded.</EmptyState>
            ) : (
              notes.map((note) => (
                <article
                  key={note.id}
                  className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
                >
                  <div className="flex items-center justify-between gap-3">
                    <h3 className="font-semibold capitalize">
                      {note.attendance_status} attendance
                    </h3>
                    <span className="text-xs text-slate-500">
                      {formatDateTime(note.created_at)}
                    </span>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-slate-700">
                    {note.performance_notes ?? note.skills_covered ?? "No summary added."}
                  </p>
                  {note.homework_assigned && (
                    <p className="mt-3 text-sm text-slate-600">
                      <strong>Homework:</strong> {note.homework_assigned}
                    </p>
                  )}
                </article>
              ))
            )}
          </div>
        </section>

        <section id="progress" className="scroll-mt-6 pb-8">
          <h2 className="text-xl font-bold">Progress reports</h2>
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            {reports.length === 0 ? (
              <EmptyState>No progress reports have been created.</EmptyState>
            ) : (
              reports.map((report) => {
                const student = Array.isArray(report.student)
                  ? report.student[0]
                  : report.student;

                return (
                <article
                  key={report.id}
                  className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
                >
                  <h3 className="font-semibold">
                    {student?.first_name} {student?.last_name}
                  </h3>
                  <p className="mt-1 text-sm font-medium text-slate-500">
                    {report.reporting_period}
                  </p>
                  <dl className="mt-4 grid gap-3 text-sm">
                    <div>
                      <dt className="font-semibold">Strengths</dt>
                      <dd className="mt-1 text-slate-600">
                        {report.strengths ?? "Not recorded"}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-semibold">Next goals</dt>
                      <dd className="mt-1 text-slate-600">
                        {report.next_goals ?? "Not recorded"}
                      </dd>
                    </div>
                  </dl>
                </article>
                );
              })
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
