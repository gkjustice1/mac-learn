import Link from "next/link";
import { redirect } from "next/navigation";

import { logout } from "@/app/actions";
import { requireRole } from "@/lib/auth/authorization";
import { getAuthorizationContext } from "@/lib/auth/context";
import { createClient } from "@/lib/supabase/server";

const PAGE_SIZE = 100;
const MAX_PAGE = Math.floor(2147483647 / PAGE_SIZE) + 1;

type SearchParams = {
  classroomPage?: string;
  studentPage?: string;
  recordPage?: string;
};

type ClassroomRow = {
  id: string;
  organization_id: string;
  site_id: string | null;
  name: string;
  code: string | null;
  status: string | null;
};

type StudentRow = {
  id: string;
  first_name: string;
  last_name: string;
  grade_level: string | null;
  school_name: string | null;
  organization_id: string;
  primary_site_id: string | null;
  classrooms: Array<{
    classroom_id: string;
    classroom_name: string;
    organization_id: string;
    site_id: string | null;
  }>;
};

type RecordRow = {
  id: string;
  organization_id: string;
  classroom_id: string;
  student_id: string;
  record_type: string;
  content: string;
  occurred_on: string;
  site_id: string | null;
  classroom_name: string;
  student_first_name: string;
  student_last_name: string;
};

function EmptyState({ children }: { children: React.ReactNode }) {
  return (
    <p className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-600">
      {children}
    </p>
  );
}

function pageNumber(value: string | undefined) {
  const parsed = Number(value ?? "1");
  return Number.isInteger(parsed) && parsed > 0 ? Math.min(parsed, MAX_PAGE) : 1;
}

function pageHref(
  params: SearchParams,
  parameter: keyof SearchParams,
  value: number,
  anchor: string
) {
  const query = new URLSearchParams();
  for (const key of ["classroomPage", "studentPage", "recordPage"] as const) {
    const current = key === parameter ? String(value) : params[key];
    if (current && current !== "1") query.set(key, current);
  }
  const serialized = query.toString();
  return `${serialized ? `?${serialized}` : ""}#${anchor}`;
}

function PageLinks({
  page,
  count,
  parameter,
  anchor,
  params,
}: {
  page: number;
  count: number;
  parameter: keyof SearchParams;
  anchor: string;
  params: SearchParams;
}) {
  const pages = Math.max(1, Math.ceil(count / PAGE_SIZE));
  if (pages <= 1) return null;

  return (
    <nav className="mt-4 flex items-center gap-3 text-sm font-semibold">
      {page > 1 ? (
        <Link
          className="rounded-lg border border-slate-300 bg-white px-3 py-2"
          href={pageHref(params, parameter, page - 1, anchor)}
        >
          Previous
        </Link>
      ) : null}
      <span className="text-slate-500">Page {page} of {pages}</span>
      {page < pages ? (
        <Link
          className="rounded-lg border border-slate-300 bg-white px-3 py-2"
          href={pageHref(params, parameter, page + 1, anchor)}
        >
          Next
        </Link>
      ) : null}
    </nav>
  );
}

export default async function EducatorPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const context = await getAuthorizationContext();
  const assignment = context.roles.find(
    (role) => role.role === "teacher" || role.role === "academic_lead"
  );
  if (!assignment?.organizationId) redirect("/unauthorized");

  await requireRole(assignment.role, {
    organizationId: assignment.organizationId,
    siteId: assignment.siteId,
  });

  const params = await searchParams;
  const classroomPage = pageNumber(params.classroomPage);
  const studentPage = pageNumber(params.studentPage);
  const recordPage = pageNumber(params.recordPage);
  const supabase = await createClient();

  const classroomResult = await supabase.rpc("mac_get_educator_classroom_page", {
    p_offset: (classroomPage - 1) * PAGE_SIZE,
    p_limit: PAGE_SIZE,
  });
  if (classroomResult.error) {
    throw new Error(`Unable to load Educator classrooms: ${classroomResult.error.message}`);
  }
  const classroomPayload = (classroomResult.data ?? {
    total_count: 0,
    rows: [],
  }) as { total_count: number; rows: ClassroomRow[] };
  const classrooms = classroomPayload.rows ?? [];
  const classroomCount = Number(classroomPayload.total_count ?? 0);

  const studentResult = await supabase.rpc("mac_get_educator_student_page", {
    p_offset: (studentPage - 1) * PAGE_SIZE,
    p_limit: PAGE_SIZE,
  });
  if (studentResult.error) {
    throw new Error(`Unable to load Educator students: ${studentResult.error.message}`);
  }
  const studentPayload = (studentResult.data ?? {
    total_count: 0,
    rows: [],
  }) as { total_count: number; rows: StudentRow[] };
  const students = studentPayload.rows ?? [];
  const studentCount = Number(studentPayload.total_count ?? 0);

  const recordResult = await supabase.rpc("mac_get_educator_instructional_record_page", {
    p_offset: (recordPage - 1) * PAGE_SIZE,
    p_limit: PAGE_SIZE,
  });
  if (recordResult.error) {
    throw new Error(`Unable to load Educator instructional records: ${recordResult.error.message}`);
  }
  const recordPayload = (recordResult.data ?? {
    total_count: 0,
    rows: [],
  }) as { total_count: number; rows: RecordRow[] };
  const records = recordPayload.rows ?? [];
  const recordCount = Number(recordPayload.total_count ?? 0);

  const referencedOrganizationIds = [
    ...new Set([
      assignment.organizationId,
      ...classrooms.map((row) => row.organization_id),
      ...students.map((row) => row.organization_id),
      ...records.map((row) => row.organization_id),
    ]),
  ];
  const referencedSiteIds = [
    ...new Set(
      [
        ...(assignment.siteId ? [assignment.siteId] : []),
        ...classrooms.map((row) => row.site_id),
        ...students.map((row) => row.primary_site_id),
        ...students.flatMap((row) => row.classrooms.map((classroom) => classroom.site_id)),
        ...records.map((row) => row.site_id),
      ].filter((id): id is string => Boolean(id))
    ),
  ];

  const organizationNames = new Map<string, string>();
  for (let offset = 0; offset < referencedOrganizationIds.length; offset += PAGE_SIZE) {
    const result = await supabase
      .from("organizations")
      .select("id, name")
      .in("id", referencedOrganizationIds.slice(offset, offset + PAGE_SIZE))
      .order("id");
    if (result.error) {
      throw new Error(`Unable to load Educator organization names: ${result.error.message}`);
    }
    for (const row of result.data ?? []) organizationNames.set(row.id, row.name);
  }

  const siteNames = new Map<string, string>();
  for (let offset = 0; offset < referencedSiteIds.length; offset += PAGE_SIZE) {
    const result = await supabase
      .from("sites")
      .select("id, name")
      .in("id", referencedSiteIds.slice(offset, offset + PAGE_SIZE))
      .order("id");
    if (result.error) {
      throw new Error(`Unable to load Educator site names: ${result.error.message}`);
    }
    for (const row of result.data ?? []) siteNames.set(row.id, row.name);
  }

  const roleLabel = assignment.role === "academic_lead" ? "Academic Lead" : "Educator";
  const scopeLabel = (organizationId: string, siteId?: string | null) =>
    [
      organizationNames.get(organizationId) ?? "Assigned organization",
      siteId ? siteNames.get(siteId) ?? "Assigned site" : null,
    ]
      .filter(Boolean)
      .join(" · ");
  const assignmentScopeLabel = scopeLabel(assignment.organizationId, assignment.siteId);

  return (
    <main className="min-h-screen bg-slate-50 text-slate-950">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-lime-700">MAC Learn</p>
            <p className="mt-1 text-lg font-bold">Educator workspace</p>
          </div>
          <div className="flex items-center gap-3">
            <span className="rounded-full bg-lime-100 px-3 py-1 text-sm font-semibold text-lime-800">{roleLabel}</span>
            <form action={logout}>
              <button className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold">Sign out</button>
            </form>
          </div>
        </div>
      </header>

      <div className="mx-auto grid max-w-7xl gap-8 px-6 py-8">
        <section>
          <p className="text-sm font-semibold uppercase tracking-[0.16em] text-slate-500">{assignmentScopeLabel}</p>
          <h1 className="mt-2 text-3xl font-bold">Welcome, {context.user.user_metadata?.first_name ?? roleLabel}</h1>
          <p className="mt-2 text-sm text-slate-600">Review your assigned classrooms, enrolled students, and instructional records.</p>
        </section>

        <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[
            ["Assigned classrooms", classroomCount],
            ["Enrolled students", studentCount],
            ["Instructional records", recordCount],
          ].map(([label, value]) => (
            <article key={String(label)} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <p className="text-sm text-slate-500">{label}</p>
              <p className="mt-2 text-3xl font-bold">{value}</p>
            </article>
          ))}
        </section>

        <section id="classrooms">
          <h2 className="text-xl font-bold">Classrooms</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {classrooms.length ? (
              classrooms.map((classroom) => (
                <article key={classroom.id} className="rounded-2xl border border-slate-200 bg-white p-5">
                  <h3 className="font-semibold">{classroom.name}</h3>
                  <p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(classroom.organization_id, classroom.site_id)}</p>
                  <p className="mt-2 text-sm text-slate-600">{classroom.code ?? "No classroom code"} · {(classroom.status ?? "unspecified").replaceAll("_", " ")}</p>
                </article>
              ))
            ) : (
              <EmptyState>No classrooms are assigned.</EmptyState>
            )}
          </div>
          <PageLinks page={classroomPage} count={classroomCount} parameter="classroomPage" anchor="classrooms" params={params} />
        </section>

        <section id="students">
          <h2 className="text-xl font-bold">Assigned students</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {students.length ? (
              students.map((student) => (
                <article key={student.id} className="rounded-2xl border border-slate-200 bg-white p-5">
                  <h3 className="font-semibold">{student.first_name} {student.last_name}</h3>
                  <p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(student.organization_id, student.primary_site_id)}</p>
                  <p className="mt-2 text-sm text-slate-600">Grade {student.grade_level ?? "unspecified"}{student.school_name ? ` · ${student.school_name}` : ""}</p>
                  <p className="mt-2 text-xs text-slate-500">{student.classrooms.map((classroom) => classroom.classroom_name).join(", ") || "Assigned classroom"}</p>
                </article>
              ))
            ) : (
              <EmptyState>No students are enrolled in your assigned classrooms.</EmptyState>
            )}
          </div>
          <PageLinks page={studentPage} count={studentCount} parameter="studentPage" anchor="students" params={params} />
        </section>

        <section id="instructional-records" className="pb-8">
          <h2 className="text-xl font-bold">Instructional records</h2>
          <div className="mt-4 grid gap-3">
            {records.length ? (
              records.map((record) => (
                <article key={record.id} className="rounded-2xl border border-slate-200 bg-white p-5">
                  <p className="text-sm font-semibold capitalize">{record.record_type.replaceAll("_", " ")}</p>
                  <p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{scopeLabel(record.organization_id, record.site_id)}</p>
                  <p className="mt-2 text-sm font-medium">{record.student_first_name} {record.student_last_name} · {record.classroom_name}</p>
                  <p className="mt-2 text-sm leading-6 text-slate-600">{record.content}</p>
                  <p className="mt-2 text-xs text-slate-500">{record.occurred_on}</p>
                </article>
              ))
            ) : (
              <EmptyState>No instructional records are available.</EmptyState>
            )}
          </div>
          <PageLinks page={recordPage} count={recordCount} parameter="recordPage" anchor="instructional-records" params={params} />
        </section>
      </div>
    </main>
  );
}
