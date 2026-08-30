import { AdminShell } from "@/components/admin/AdminShell";
import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

import { SessionAssignmentForm } from "./SessionAssignmentForm";

export default async function TutorOperationsPage() {
  await requirePlatformAdmin();
  const supabase = await createClient();
  const [students, tutors, subjects] = await Promise.all([
    supabase.rpc("mac_platform_admin_student_options"),
    supabase.rpc("mac_platform_admin_tutor_options"),
    supabase.from("subjects").select("id, name").order("name"),
  ]);
  const error = students.error ?? tutors.error ?? subjects.error;
  if (error) throw new Error(`Unable to load Tutor operations: ${error.message}`);
  return <AdminShell activeItem="access"><div className="grid gap-6"><header><p className="text-sm font-semibold uppercase tracking-widest text-slate-500">Platform administration</p><h2 className="mt-2 text-3xl font-bold">Tutor operations</h2><p className="mt-2 text-sm text-slate-600">Assign an active student and scheduled session to an authorized Tutor.</p></header><SessionAssignmentForm students={students.data ?? []} tutors={tutors.data ?? []} subjects={(subjects.data ?? []).map((x) => ({ id: x.id, label: x.name }))} /></div></AdminShell>;
}
