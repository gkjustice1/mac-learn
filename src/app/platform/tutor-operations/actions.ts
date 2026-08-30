"use server";

import { revalidatePath } from "next/cache";

import { requirePlatformAdmin } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

export type ScheduleState = { error: string | null; scheduled: boolean };

export async function scheduleTutorSession(
  _previous: ScheduleState,
  formData: FormData
): Promise<ScheduleState> {
  await requirePlatformAdmin();
  const studentId = String(formData.get("student_id") ?? "");
  const tutorId = String(formData.get("tutor_id") ?? "");
  const subjectId = String(formData.get("subject_id") ?? "") || null;
  const startTime = String(formData.get("start_time") ?? "");
  const endTime = String(formData.get("end_time") ?? "");
  const zoomLink = String(formData.get("zoom_link") ?? "").trim() || null;

  if (!studentId || !tutorId || !startTime || !endTime) {
    return { error: "Student, Tutor, start time, and end time are required.", scheduled: false };
  }
  if (new Date(endTime) <= new Date(startTime)) {
    return { error: "End time must be after start time.", scheduled: false };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("mac_platform_admin_schedule_session", {
    p_student_id: studentId,
    p_tutor_id: tutorId,
    p_subject_id: subjectId,
    p_start_time: new Date(startTime).toISOString(),
    p_end_time: new Date(endTime).toISOString(),
    p_zoom_link: zoomLink,
  });
  if (error) return { error: error.message, scheduled: false };
  revalidatePath("/platform/tutor-operations");
  revalidatePath("/tutor");
  return { error: null, scheduled: true };
}
