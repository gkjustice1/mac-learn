"use server";

import { revalidatePath } from "next/cache";

import { requireAnyRole } from "@/lib/auth/authorization";
import { createClient } from "@/lib/supabase/server";

export type TutorActionState = { error: string | null; success: string | null };
const initialError = (message: string): TutorActionState => ({ error: message, success: null });

async function tutorClient() {
  await requireAnyRole(["tutor"]);
  const supabase = await createClient();
  const { data: tutorId, error } = await supabase.rpc("mac_current_tutor_id");
  if (error || !tutorId) throw new Error("Your active Tutor profile could not be resolved.");
  return { supabase, tutorId };
}

export async function createTutorAvailability(_previous: TutorActionState, formData: FormData): Promise<TutorActionState> {
  const day = Number(formData.get("day_of_week"));
  const start = String(formData.get("start_time") ?? "");
  const end = String(formData.get("end_time") ?? "");
  if (!Number.isInteger(day) || day < 0 || day > 6 || !start || !end) return initialError("Day, start time, and end time are required.");
  if (end <= start) return initialError("End time must be after start time.");
  const { supabase, tutorId } = await tutorClient();
  const { error } = await supabase.from("tutor_availability").insert({ tutor_id: tutorId, day_of_week: day, start_time: start, end_time: end });
  if (error) return initialError(error.message);
  revalidatePath("/tutor");
  return { error: null, success: "Availability added." };
}

export async function createTutorSessionNote(_previous: TutorActionState, formData: FormData): Promise<TutorActionState> {
  const sessionId = String(formData.get("session_id") ?? "");
  const attendance = String(formData.get("attendance_status") ?? "");
  const performance = String(formData.get("performance_notes") ?? "").trim();
  if (!sessionId || !["present", "absent", "late", "excused"].includes(attendance)) return initialError("Session and attendance are required.");
  const { supabase, tutorId } = await tutorClient();
  const { data: session, error: sessionError } = await supabase
    .from("sessions")
    .select("id, end_time")
    .eq("id", sessionId)
    .eq("tutor_id", tutorId)
    .maybeSingle();
  if (sessionError) return initialError(sessionError.message);
  if (!session) return initialError("The selected session is not assigned to this Tutor.");
  if (new Date(session.end_time).getTime() > Date.now()) {
    return initialError("Session notes can only be created after the session ends.");
  }
  const { error } = await supabase.from("session_notes").insert({ session_id: sessionId, tutor_id: tutorId, attendance_status: attendance, skills_covered: String(formData.get("skills_covered") ?? "").trim() || null, performance_notes: performance || null, homework_assigned: String(formData.get("homework_assigned") ?? "").trim() || null, parent_summary: String(formData.get("parent_summary") ?? "").trim() || null });
  if (error) return initialError(error.message);
  revalidatePath("/tutor");
  return { error: null, success: "Session note created." };
}

export async function createTutorProgressReport(_previous: TutorActionState, formData: FormData): Promise<TutorActionState> {
  const studentId = String(formData.get("student_id") ?? "");
  const period = String(formData.get("reporting_period") ?? "").trim();
  if (!studentId || !period) return initialError("Student and reporting period are required.");
  const { supabase, tutorId } = await tutorClient();
  const { error } = await supabase.from("progress_reports").insert({ student_id: studentId, tutor_id: tutorId, reporting_period: period, strengths: String(formData.get("strengths") ?? "").trim() || null, areas_for_improvement: String(formData.get("areas_for_improvement") ?? "").trim() || null, skills_mastered: String(formData.get("skills_mastered") ?? "").trim() || null, next_goals: String(formData.get("next_goals") ?? "").trim() || null, comments: String(formData.get("comments") ?? "").trim() || null });
  if (error) return initialError(error.message);
  revalidatePath("/tutor");
  return { error: null, success: "Progress report created." };
}
