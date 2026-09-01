import { redirect } from "next/navigation";

import { logout } from "@/app/actions";
import { requireRole } from "@/lib/auth/authorization";
import { getAuthorizationContext } from "@/lib/auth/context";
import { createClient } from "@/lib/supabase/server";

function EmptyState({ children }: { children: React.ReactNode }) {
  return <p className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-600">{children}</p>;
}

export default async function EducatorPage() {
  const context = await getAuthorizationContext();
  const assignment = context.roles.find((role) => role.role === "teacher" || role.role === "academic_lead");
  if (!assignment?.organizationId) redirect("/unauthorized");

  await requireRole(assignment.role, {
    organizationId: assignment.organizationId,
    siteId: assignment.siteId,
  });

  const supabase = await createClient();
  const [classroomsResult, assignmentsResult, enrollmentsResult, studentsResult, recordsResult, organizationResult, siteResult] = await Promise.all([
    supabase.from("classrooms").select("id, organization_id, site_id, name, code, status").order("name"),
    supabase.from("classroom_educators").select("id, classroom_id, assignment_role, status, assigned_from, assigned_until"),
    supabase.from("classroom_student_enrollments").select("id, classroom_id, student_id, status, enrolled_from, enrolled_until"),
    supabase.from("students").select("id, first_name, last_name, grade_level, school_name, organization_id, primary_site_id").order("last_name").order("first_name"),
    supabase.from("educator_instructional_records").select("id, classroom_id, student_id, record_type, content, occurred_on").order("occurred_on", { ascending: false }),
    supabase.from("organizations").select("id, name").eq("id", assignment.organizationId).maybeSingle(),
    assignment.siteId ? supabase.from("sites").select("id, name").eq("id", assignment.siteId).maybeSingle() : Promise.resolve({ data: null, error: null }),
  ]);

  const failure = [classroomsResult, assignmentsResult, enrollmentsResult, studentsResult, recordsResult, organizationResult, siteResult].find((result) => result.error);
  if (failure?.error) throw new Error(`Unable to load Educator workspace: ${failure.error.message}`);

  const classrooms = classroomsResult.data ?? [];
  const classroomAssignments = assignmentsResult.data ?? [];
  const enrollments = enrollmentsResult.data ?? [];
  const students = studentsResult.data ?? [];
  const records = recordsResult.data ?? [];
  const classroomNames = new Map(classrooms.map((classroom) => [classroom.id, classroom.name]));
  const studentNames = new Map(students.map((student) => [student.id, `${student.first_name} ${student.last_name}`]));
  const roleLabel = assignment.role === "academic_lead" ? "Academic Lead" : "Educator";
  const scopeLabel = [organizationResult.data?.name ?? "Assigned organization", siteResult.data?.name].filter(Boolean).join(" · ");

  return <main className="min-h-screen bg-slate-50 text-slate-950">
    <header className="border-b border-slate-200 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5"><div><p className="text-xs font-bold uppercase tracking-[0.2em] text-lime-700">MAC Learn</p><p className="mt-1 text-lg font-bold">Educator workspace</p></div><div className="flex items-center gap-3"><span className="rounded-full bg-lime-100 px-3 py-1 text-sm font-semibold text-lime-800">{roleLabel}</span><form action={logout}><button className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold">Sign out</button></form></div></div></header>
    <div className="mx-auto grid max-w-7xl gap-8 px-6 py-8">
      <section><p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">{scopeLabel}</p><h1 className="mt-2 text-3xl font-bold">Welcome, {context.user.user_metadata?.first_name ?? roleLabel}</h1><p className="mt-2 text-sm text-slate-600">Review your assigned classrooms, enrolled students, and instructional records.</p><nav className="mt-5 flex flex-wrap gap-2">{["Classrooms", "Students", "Instructional records"].map((label) => <a key={label} href={`#${label.toLowerCase().replaceAll(" ", "-")}`} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold">{label}</a>)}</nav></section>
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{[["Assigned classrooms", classrooms.length], ["Classroom assignments", classroomAssignments.length], ["Enrolled students", students.length], ["Instructional records", records.length]].map(([label, value]) => <article key={String(label)} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm text-slate-500">{label}</p><p className="mt-2 text-3xl font-bold">{value}</p></article>)}</section>
      <section id="classrooms"><h2 className="text-xl font-bold">Classrooms</h2><div className="mt-4 grid gap-3 md:grid-cols-2">{classrooms.length ? classrooms.map((classroom) => <article key={classroom.id} className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-semibold">{classroom.name}</h3><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel}</p><p className="mt-2 text-sm text-slate-600">{classroom.code ?? "No classroom code"} · {(classroom.status ?? "unspecified").replaceAll("_", " ")}</p></article>) : <EmptyState>No classrooms are assigned.</EmptyState>}</div></section>
      <section id="students"><h2 className="text-xl font-bold">Assigned students</h2><div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">{students.length ? students.map((student) => <article key={student.id} className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-semibold">{student.first_name} {student.last_name}</h3><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel}</p><p className="mt-2 text-sm text-slate-600">Grade {student.grade_level}{student.school_name ? ` · ${student.school_name}` : ""}</p><p className="mt-2 text-xs text-slate-500">{enrollments.filter((enrollment) => enrollment.student_id === student.id).map((enrollment) => classroomNames.get(enrollment.classroom_id)).filter(Boolean).join(", ") || "Assigned classroom"}</p></article>) : <EmptyState>No students are enrolled in your assigned classrooms.</EmptyState>}</div></section>
      <section id="instructional-records" className="pb-8"><h2 className="text-xl font-bold">Instructional records</h2><div className="mt-4 grid gap-3">{records.length ? records.map((record) => <article key={record.id} className="rounded-2xl border border-slate-200 bg-white p-5"><p className="text-sm font-semibold capitalize">{record.record_type.replaceAll("_", " ")}</p><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel}</p><p className="mt-2 text-sm font-medium">{studentNames.get(record.student_id) ?? "Assigned student"} · {classroomNames.get(record.classroom_id) ?? "Assigned classroom"}</p><p className="mt-2 text-sm leading-6 text-slate-600">{record.content}</p><p className="mt-2 text-xs text-slate-500">{record.occurred_on}</p></article>) : <EmptyState>No instructional records are available.</EmptyState>}</div></section>
    </div>
  </main>;
}
