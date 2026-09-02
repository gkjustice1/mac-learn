import Link from "next/link";
import { redirect } from "next/navigation";

import { logout } from "@/app/actions";
import { requireRole } from "@/lib/auth/authorization";
import { getAuthorizationContext } from "@/lib/auth/context";
import { createClient } from "@/lib/supabase/server";

const PAGE_SIZE = 100;

type SearchParams = { classroomPage?: string; studentPage?: string; recordPage?: string };

type ClassroomRow = {
  id: string;
  organization_id: string;
  site_id: string | null;
  name: string;
  code: string | null;
  status: string | null;
};

function EmptyState({ children }: { children: React.ReactNode }) {
  return <p className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-600">{children}</p>;
}

function pageNumber(value: string | undefined) {
  const parsed = Number(value ?? "1");
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 1;
}

function PageLinks({ page, count, parameter, anchor }: { page: number; count: number; parameter: string; anchor: string }) {
  const pages = Math.max(1, Math.ceil(count / PAGE_SIZE));
  if (pages <= 1) return null;
  return <nav className="mt-4 flex items-center gap-3 text-sm font-semibold">
    {page > 1 ? <Link className="rounded-lg border border-slate-300 bg-white px-3 py-2" href={`?${parameter}=${page - 1}#${anchor}`}>Previous</Link> : null}
    <span className="text-slate-500">Page {page} of {pages}</span>
    {page < pages ? <Link className="rounded-lg border border-slate-300 bg-white px-3 py-2" href={`?${parameter}=${page + 1}#${anchor}`}>Next</Link> : null}
  </nav>;
}

export default async function EducatorPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const context = await getAuthorizationContext();
  const assignment = context.roles.find((role) => role.role === "teacher" || role.role === "academic_lead");
  if (!assignment?.organizationId) redirect("/unauthorized");

  await requireRole(assignment.role, { organizationId: assignment.organizationId, siteId: assignment.siteId });

  const params = await searchParams;
  const classroomPage = pageNumber(params.classroomPage);
  const studentPage = pageNumber(params.studentPage);
  const recordPage = pageNumber(params.recordPage);
  const supabase = await createClient();
  const today = new Date().toISOString().slice(0, 10);

  // Anchor the workspace to the signed-in educator's own active relationship rows.
  // Explicit user_id filtering prevents a second admin role from widening this dataset.
  const classroomAssignments: Array<{ id: string; classroom_id: string; assignment_role: string; status: string; assigned_from: string; assigned_until: string | null }> = [];
  let assignmentFrom = 0;
  while (true) {
    const result = await supabase.from("classroom_educators")
      .select("id, classroom_id, assignment_role, status, assigned_from, assigned_until")
      .eq("user_id", context.user.id)
      .eq("status", "active")
      .lte("assigned_from", today)
      .or(`assigned_until.is.null,assigned_until.gte.${today}`)
      .order("classroom_id")
      .order("id")
      .range(assignmentFrom, assignmentFrom + PAGE_SIZE - 1);
    if (result.error) throw new Error(`Unable to load Educator assignments: ${result.error.message}`);
    const rows = result.data ?? [];
    classroomAssignments.push(...rows);
    if (rows.length < PAGE_SIZE) break;
    assignmentFrom += PAGE_SIZE;
  }

  const candidateClassroomIds = [...new Set(classroomAssignments.map((row) => row.classroom_id))];
  const activeClassrooms: ClassroomRow[] = [];
  for (let offset = 0; offset < candidateClassroomIds.length; offset += PAGE_SIZE) {
    const ids = candidateClassroomIds.slice(offset, offset + PAGE_SIZE);
    const result = await supabase.from("classrooms")
      .select("id, organization_id, site_id, name, code, status")
      .in("id", ids)
      .eq("status", "active")
      .order("name")
      .order("id");
    if (result.error) throw new Error(`Unable to validate Educator classrooms: ${result.error.message}`);
    activeClassrooms.push(...(result.data ?? []));
  }
  activeClassrooms.sort((left, right) => left.name.localeCompare(right.name) || left.id.localeCompare(right.id));

  const classroomIds = activeClassrooms.map((row) => row.id);
  const classroomCount = classroomIds.length;
  const classroomFrom = (classroomPage - 1) * PAGE_SIZE;
  const classrooms = activeClassrooms.slice(classroomFrom, classroomFrom + PAGE_SIZE);

  // Fetch every current membership for the validated active classroom set in deterministic chunks.
  const enrollments: Array<{ id: string; organization_id: string; classroom_id: string; student_id: string; status: string; enrolled_from: string; enrolled_until: string | null }> = [];
  if (classroomIds.length) {
    for (let classroomOffset = 0; classroomOffset < classroomIds.length; classroomOffset += PAGE_SIZE) {
      const classroomChunk = classroomIds.slice(classroomOffset, classroomOffset + PAGE_SIZE);
      let enrollmentFrom = 0;
      while (true) {
        const result = await supabase.from("classroom_student_enrollments")
          .select("id, organization_id, classroom_id, student_id, status, enrolled_from, enrolled_until")
          .in("classroom_id", classroomChunk)
          .eq("status", "active")
          .lte("enrolled_from", today)
          .or(`enrolled_until.is.null,enrolled_until.gte.${today}`)
          .order("student_id")
          .order("classroom_id")
          .order("id")
          .range(enrollmentFrom, enrollmentFrom + PAGE_SIZE - 1);
        if (result.error) throw new Error(`Unable to load Educator enrollments: ${result.error.message}`);
        const rows = result.data ?? [];
        enrollments.push(...rows);
        if (rows.length < PAGE_SIZE) break;
        enrollmentFrom += PAGE_SIZE;
      }
    }
  }

  const accessibleStudentIds = [...new Set(enrollments.map((row) => row.student_id))].sort();
  const studentCount = accessibleStudentIds.length;
  const studentFrom = (studentPage - 1) * PAGE_SIZE;
  const studentPageIds = accessibleStudentIds.slice(studentFrom, studentFrom + PAGE_SIZE);

  const studentsResult = studentPageIds.length
    ? await supabase.from("students")
        .select("id, first_name, last_name, grade_level, school_name, organization_id, primary_site_id")
        .in("id", studentPageIds)
        .order("last_name")
        .order("first_name")
        .order("id")
    : { data: [], error: null };
  if (studentsResult.error) throw new Error(`Unable to load Educator students: ${studentsResult.error.message}`);
  const students = studentsResult.data ?? [];

  const recordFrom = (recordPage - 1) * PAGE_SIZE;
  const recordsResult = classroomIds.length
    ? await supabase.from("educator_instructional_records")
        .select("id, organization_id, classroom_id, student_id, record_type, content, occurred_on", { count: "exact" })
        .in("classroom_id", classroomIds)
        .order("occurred_on", { ascending: false })
        .order("id", { ascending: false })
        .range(recordFrom, recordFrom + PAGE_SIZE - 1)
    : { data: [], error: null, count: 0 };
  if (recordsResult.error) throw new Error(`Unable to load Educator instructional records: ${recordsResult.error.message}`);

  const records = recordsResult.data ?? [];
  const recordCount = recordsResult.count ?? records.length;
  const recordStudentIds = [...new Set(records.map((record) => record.student_id))];

  const recordStudentsResult = recordStudentIds.length
    ? await supabase.from("students").select("id, first_name, last_name").in("id", recordStudentIds).order("id")
    : { data: [], error: null };
  if (recordStudentsResult.error) throw new Error(`Unable to load Educator record student names: ${recordStudentsResult.error.message}`);

  // All active assigned classroom names are already loaded, so visible Student membership
  // labels cannot disappear merely because the classroom is on a different classroom page.
  const classroomNames = new Map(activeClassrooms.map((classroom) => [classroom.id, classroom.name]));
  const classroomsById = new Map(activeClassrooms.map((classroom) => [classroom.id, classroom]));
  const studentNames = new Map((recordStudentsResult.data ?? []).map((student) => [student.id, `${student.first_name} ${student.last_name}`]));
  for (const student of students) studentNames.set(student.id, `${student.first_name} ${student.last_name}`);

  // Fetch only scope names actually referenced by this rendered workspace instead of
  // relying on unbounded organization/site lookups that can hit Supabase max_rows.
  const referencedOrganizationIds = [...new Set([
    assignment.organizationId,
    ...classrooms.map((row) => row.organization_id),
    ...students.map((row) => row.organization_id),
    ...records.map((row) => row.organization_id),
  ])];
  const recordSiteIds = records
    .map((record) => classroomsById.get(record.classroom_id)?.site_id)
    .filter((siteId): siteId is string => Boolean(siteId));
  const referencedSiteIds = [...new Set([
    ...(assignment.siteId ? [assignment.siteId] : []),
    ...classrooms.map((row) => row.site_id).filter((siteId): siteId is string => Boolean(siteId)),
    ...students.map((row) => row.primary_site_id).filter((siteId): siteId is string => Boolean(siteId)),
    ...recordSiteIds,
  ])];

  const organizationNames = new Map<string, string>();
  for (let offset = 0; offset < referencedOrganizationIds.length; offset += PAGE_SIZE) {
    const ids = referencedOrganizationIds.slice(offset, offset + PAGE_SIZE);
    const result = await supabase.from("organizations").select("id, name").in("id", ids).order("id");
    if (result.error) throw new Error(`Unable to load Educator organization names: ${result.error.message}`);
    for (const row of result.data ?? []) organizationNames.set(row.id, row.name);
  }

  const siteNames = new Map<string, string>();
  for (let offset = 0; offset < referencedSiteIds.length; offset += PAGE_SIZE) {
    const ids = referencedSiteIds.slice(offset, offset + PAGE_SIZE);
    const result = await supabase.from("sites").select("id, organization_id, name").in("id", ids).order("id");
    if (result.error) throw new Error(`Unable to load Educator site names: ${result.error.message}`);
    for (const row of result.data ?? []) siteNames.set(row.id, row.name);
  }

  const roleLabel = assignment.role === "academic_lead" ? "Academic Lead" : "Educator";
  const assignmentScopeLabel = [organizationNames.get(assignment.organizationId) ?? "Assigned organization", assignment.siteId ? siteNames.get(assignment.siteId) : null].filter(Boolean).join(" · ");
  const scopeLabel = (organizationId: string, siteId?: string | null) => [organizationNames.get(organizationId) ?? "Assigned organization", siteId ? siteNames.get(siteId) ?? "Assigned site" : null].filter(Boolean).join(" · ");

  return <main className="min-h-screen bg-slate-50 text-slate-950">
    <header className="border-b border-slate-200 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5"><div><p className="text-xs font-bold uppercase tracking-[0.2em] text-lime-700">MAC Learn</p><p className="mt-1 text-lg font-bold">Educator workspace</p></div><div className="flex items-center gap-3"><span className="rounded-full bg-lime-100 px-3 py-1 text-sm font-semibold text-lime-800">{roleLabel}</span><form action={logout}><button className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold">Sign out</button></form></div></div></header>
    <div className="mx-auto grid max-w-7xl gap-8 px-6 py-8">
      <section><p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">{assignmentScopeLabel}</p><h1 className="mt-2 text-3xl font-bold">Welcome, {context.user.user_metadata?.first_name ?? roleLabel}</h1><p className="mt-2 text-sm text-slate-600">Review your assigned classrooms, enrolled students, and instructional records.</p><nav className="mt-5 flex flex-wrap gap-2">{["Classrooms", "Students", "Instructional records"].map((label) => <a key={label} href={`#${label.toLowerCase().replaceAll(" ", "-")}`} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold">{label}</a>)}</nav></section>
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{[["Assigned classrooms", classroomCount], ["Active classroom assignments", classroomAssignments.filter((row) => classroomNames.has(row.classroom_id)).length], ["Enrolled students", studentCount], ["Instructional records", recordCount]].map(([label, value]) => <article key={String(label)} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm text-slate-500">{label}</p><p className="mt-2 text-3xl font-bold">{value}</p></article>)}</section>
      <section id="classrooms"><h2 className="text-xl font-bold">Classrooms</h2><div className="mt-4 grid gap-3 md:grid-cols-2">{classrooms.length ? classrooms.map((classroom) => <article key={classroom.id} className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-semibold">{classroom.name}</h3><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(classroom.organization_id, classroom.site_id)}</p><p className="mt-2 text-sm text-slate-600">{classroom.code ?? "No classroom code"} · {(classroom.status ?? "unspecified").replaceAll("_", " ")}</p></article>) : <EmptyState>No classrooms are assigned.</EmptyState>}</div><PageLinks page={classroomPage} count={classroomCount} parameter="classroomPage" anchor="classrooms" /></section>
      <section id="students"><h2 className="text-xl font-bold">Assigned students</h2><div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">{students.length ? students.map((student) => <article key={student.id} className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-semibold">{student.first_name} {student.last_name}</h3><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(student.organization_id, student.primary_site_id)}</p><p className="mt-2 text-sm text-slate-600">Grade {student.grade_level}{student.school_name ? ` · ${student.school_name}` : ""}</p><p className="mt-2 text-xs text-slate-500">{enrollments.filter((enrollment) => enrollment.student_id === student.id).map((enrollment) => classroomNames.get(enrollment.classroom_id)).filter(Boolean).join(", ") || "Assigned classroom"}</p></article>) : <EmptyState>No students are enrolled in your assigned classrooms.</EmptyState>}</div><PageLinks page={studentPage} count={studentCount} parameter="studentPage" anchor="students" /></section>
      <section id="instructional-records" className="pb-8"><h2 className="text-xl font-bold">Instructional records</h2><div className="mt-4 grid gap-3">{records.length ? records.map((record) => { const classroom = classroomsById.get(record.classroom_id); return <article key={record.id} className="rounded-2xl border border-slate-200 bg-white p-5"><p className="text-sm font-semibold capitalize">{record.record_type.replaceAll("_", " ")}</p><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(record.organization_id, classroom?.site_id)}</p><p className="mt-2 text-sm font-medium">{studentNames.get(record.student_id) ?? "Assigned student"} · {classroomNames.get(record.classroom_id) ?? "Assigned classroom"}</p><p className="mt-2 text-sm leading-6 text-slate-600">{record.content}</p><p className="mt-2 text-xs text-slate-500">{record.occurred_on}</p></article>; }) : <EmptyState>No instructional records are available.</EmptyState>}</div><PageLinks page={recordPage} count={recordCount} parameter="recordPage" anchor="instructional-records" /></section>
    </div>
  </main>;
}
