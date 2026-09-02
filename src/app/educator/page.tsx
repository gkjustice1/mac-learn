import Link from "next/link";
import { redirect } from "next/navigation";

import { logout } from "@/app/actions";
import { requireRole } from "@/lib/auth/authorization";
import { getAuthorizationContext } from "@/lib/auth/context";
import { createClient } from "@/lib/supabase/server";

const PAGE_SIZE = 100;

function EmptyState({ children }: { children: React.ReactNode }) {
  return <p className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-600">{children}</p>;
}

function pageNumber(value: string | undefined) {
  const parsed = Number(value ?? "1");
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 1;
}

function PageLinks({ page, count, parameter }: { page: number; count: number; parameter: string }) {
  const pages = Math.max(1, Math.ceil(count / PAGE_SIZE));
  if (pages <= 1) return null;
  return <nav className="mt-4 flex items-center gap-3 text-sm font-semibold">
    {page > 1 ? <Link className="rounded-lg border border-slate-300 bg-white px-3 py-2" href={`?${parameter}=${page - 1}#${parameter === "studentPage" ? "students" : "instructional-records"}`}>Previous</Link> : null}
    <span className="text-slate-500">Page {page} of {pages}</span>
    {page < pages ? <Link className="rounded-lg border border-slate-300 bg-white px-3 py-2" href={`?${parameter}=${page + 1}#${parameter === "studentPage" ? "students" : "instructional-records"}`}>Next</Link> : null}
  </nav>;
}

export default async function EducatorPage({ searchParams }: { searchParams: Promise<{ studentPage?: string; recordPage?: string }> }) {
  const context = await getAuthorizationContext();
  const assignment = context.roles.find((role) => role.role === "teacher" || role.role === "academic_lead");
  if (!assignment?.organizationId) redirect("/unauthorized");

  await requireRole(assignment.role, { organizationId: assignment.organizationId, siteId: assignment.siteId });

  const params = await searchParams;
  const studentPage = pageNumber(params.studentPage);
  const recordPage = pageNumber(params.recordPage);
  const studentFrom = (studentPage - 1) * PAGE_SIZE;
  const recordFrom = (recordPage - 1) * PAGE_SIZE;
  const supabase = await createClient();
  const today = new Date().toISOString().slice(0, 10);

  const [classroomsResult, assignmentsResult, studentsResult, recordsResult, organizationsResult, sitesResult] = await Promise.all([
    supabase.from("classrooms").select("id, organization_id, site_id, name, code, status").order("name"),
    supabase.from("classroom_educators").select("id, classroom_id, assignment_role, status, assigned_from, assigned_until").eq("status", "active").lte("assigned_from", today).or(`assigned_until.is.null,assigned_until.gte.${today}`),
    supabase.from("students").select("id, first_name, last_name, grade_level, school_name, organization_id, primary_site_id", { count: "exact" }).order("last_name").order("first_name").range(studentFrom, studentFrom + PAGE_SIZE - 1),
    supabase.from("educator_instructional_records").select("id, organization_id, classroom_id, student_id, record_type, content, occurred_on", { count: "exact" }).order("occurred_on", { ascending: false }).range(recordFrom, recordFrom + PAGE_SIZE - 1),
    supabase.from("organizations").select("id, name"),
    supabase.from("sites").select("id, organization_id, name"),
  ]);

  const initialFailure = [classroomsResult, assignmentsResult, studentsResult, recordsResult, organizationsResult, sitesResult].find((result) => result.error);
  if (initialFailure?.error) throw new Error(`Unable to load Educator workspace: ${initialFailure.error.message}`);

  const classrooms = classroomsResult.data ?? [];
  const classroomAssignments = assignmentsResult.data ?? [];
  const students = studentsResult.data ?? [];
  const records = recordsResult.data ?? [];
  const studentCount = studentsResult.count ?? students.length;
  const recordCount = recordsResult.count ?? records.length;

  // Enrollment memberships are needed for the students rendered on this page.
  // Fetch them in bounded chunks so Supabase max_rows cannot silently truncate memberships.
  const enrollments: Array<{ id: string; classroom_id: string; student_id: string; status: string; enrolled_from: string; enrolled_until: string | null }> = [];
  const studentIds = students.map((student) => student.id);
  if (studentIds.length) {
    let from = 0;
    while (true) {
      const result = await supabase.from("classroom_student_enrollments")
        .select("id, classroom_id, student_id, status, enrolled_from, enrolled_until")
        .in("student_id", studentIds)
        .range(from, from + PAGE_SIZE - 1);
      if (result.error) throw new Error(`Unable to load Educator enrollments: ${result.error.message}`);
      const rows = result.data ?? [];
      enrollments.push(...rows);
      if (rows.length < PAGE_SIZE) break;
      from += PAGE_SIZE;
    }
  }

  const classroomNames = new Map(classrooms.map((classroom) => [classroom.id, classroom.name]));
  const classroomsById = new Map(classrooms.map((classroom) => [classroom.id, classroom]));
  const studentNames = new Map(students.map((student) => [student.id, `${student.first_name} ${student.last_name}`]));
  const organizationNames = new Map((organizationsResult.data ?? []).map((organization) => [organization.id, organization.name]));
  const siteNames = new Map((sitesResult.data ?? []).map((site) => [site.id, site.name]));
  const roleLabel = assignment.role === "academic_lead" ? "Academic Lead" : "Educator";
  const assignmentScopeLabel = [organizationNames.get(assignment.organizationId) ?? "Assigned organization", assignment.siteId ? siteNames.get(assignment.siteId) : null].filter(Boolean).join(" · ");
  const scopeLabel = (organizationId: string, siteId?: string | null) => [organizationNames.get(organizationId) ?? "Assigned organization", siteId ? siteNames.get(siteId) ?? "Assigned site" : null].filter(Boolean).join(" · ");

  return <main className="min-h-screen bg-slate-50 text-slate-950">
    <header className="border-b border-slate-200 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5"><div><p className="text-xs font-bold uppercase tracking-[0.2em] text-lime-700">MAC Learn</p><p className="mt-1 text-lg font-bold">Educator workspace</p></div><div className="flex items-center gap-3"><span className="rounded-full bg-lime-100 px-3 py-1 text-sm font-semibold text-lime-800">{roleLabel}</span><form action={logout}><button className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold">Sign out</button></form></div></div></header>
    <div className="mx-auto grid max-w-7xl gap-8 px-6 py-8">
      <section><p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">{assignmentScopeLabel}</p><h1 className="mt-2 text-3xl font-bold">Welcome, {context.user.user_metadata?.first_name ?? roleLabel}</h1><p className="mt-2 text-sm text-slate-600">Review your assigned classrooms, enrolled students, and instructional records.</p><nav className="mt-5 flex flex-wrap gap-2">{["Classrooms", "Students", "Instructional records"].map((label) => <a key={label} href={`#${label.toLowerCase().replaceAll(" ", "-")}`} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold">{label}</a>)}</nav></section>
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{[["Assigned classrooms", classrooms.length], ["Active classroom assignments", classroomAssignments.length], ["Enrolled students", studentCount], ["Instructional records", recordCount]].map(([label, value]) => <article key={String(label)} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm text-slate-500">{label}</p><p className="mt-2 text-3xl font-bold">{value}</p></article>)}</section>
      <section id="classrooms"><h2 className="text-xl font-bold">Classrooms</h2><div className="mt-4 grid gap-3 md:grid-cols-2">{classrooms.length ? classrooms.map((classroom) => <article key={classroom.id} className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-semibold">{classroom.name}</h3><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(classroom.organization_id, classroom.site_id)}</p><p className="mt-2 text-sm text-slate-600">{classroom.code ?? "No classroom code"} · {(classroom.status ?? "unspecified").replaceAll("_", " ")}</p></article>) : <EmptyState>No classrooms are assigned.</EmptyState>}</div></section>
      <section id="students"><h2 className="text-xl font-bold">Assigned students</h2><div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">{students.length ? students.map((student) => <article key={student.id} className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-semibold">{student.first_name} {student.last_name}</h3><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(student.organization_id, student.primary_site_id)}</p><p className="mt-2 text-sm text-slate-600">Grade {student.grade_level}{student.school_name ? ` · ${student.school_name}` : ""}</p><p className="mt-2 text-xs text-slate-500">{enrollments.filter((enrollment) => enrollment.student_id === student.id).map((enrollment) => classroomNames.get(enrollment.classroom_id)).filter(Boolean).join(", ") || "Assigned classroom"}</p></article>) : <EmptyState>No students are enrolled in your assigned classrooms.</EmptyState>}</div><PageLinks page={studentPage} count={studentCount} parameter="studentPage" /></section>
      <section id="instructional-records" className="pb-8"><h2 className="text-xl font-bold">Instructional records</h2><div className="mt-4 grid gap-3">{records.length ? records.map((record) => { const classroom = classroomsById.get(record.classroom_id); return <article key={record.id} className="rounded-2xl border border-slate-200 bg-white p-5"><p className="text-sm font-semibold capitalize">{record.record_type.replaceAll("_", " ")}</p><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(record.organization_id, classroom?.site_id)}</p><p className="mt-2 text-sm font-medium">{studentNames.get(record.student_id) ?? "Assigned student"} · {classroomNames.get(record.classroom_id) ?? "Assigned classroom"}</p><p className="mt-2 text-sm leading-6 text-slate-600">{record.content}</p><p className="mt-2 text-xs text-slate-500">{record.occurred_on}</p></article>; }) : <EmptyState>No instructional records are available.</EmptyState>}</div><PageLinks page={recordPage} count={recordCount} parameter="recordPage" /></section>
    </div>
  </main>;
}
