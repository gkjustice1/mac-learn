"use client";

import { useActionState, useMemo, useState } from "react";
import { useFormStatus } from "react-dom";

import { scheduleTutorSession } from "./actions";

type Student = { id: string; label: string; organization_id: string; site_id: string | null };
type Tutor = Student;
type Option = { id: string; label: string };

function Submit({ disabled }: { disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button disabled={disabled || pending} className="rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white disabled:opacity-50">{pending ? "Scheduling..." : "Assign session"}</button>;
}

export function SessionAssignmentForm({ students, tutors, subjects }: { students: Student[]; tutors: Tutor[]; subjects: Option[] }) {
  const [state, action] = useActionState(scheduleTutorSession, { error: null, scheduled: false });
  const [studentId, setStudentId] = useState("");
  const student = students.find((item) => item.id === studentId);
  const compatibleTutors = useMemo(() => tutors.filter((tutor) => !student || (tutor.organization_id === student.organization_id && (!tutor.site_id || tutor.site_id === student.site_id))), [student, tutors]);
  const unavailable = students.length === 0 || tutors.length === 0;
  return <form action={action} className="grid gap-5 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
    {state.error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-sm text-red-800">{state.error}</p>}
    {state.scheduled && <p role="status" className="rounded-xl bg-emerald-50 p-3 text-sm text-emerald-800">Session assigned successfully.</p>}
    {students.length === 0 && <p role="status" className="rounded-xl bg-amber-50 p-3 text-sm text-amber-900">No active students are available. Create and link a student before scheduling a Tutor session.</p>}
    <label className="grid gap-2 text-sm font-semibold">Student<select aria-label="Student selection" name="student_id" required value={studentId} onChange={(e) => setStudentId(e.target.value)} className="rounded-xl border p-3 font-normal"><option value="">Select a student</option>{students.map((x) => <option key={x.id} value={x.id}>{x.label}</option>)}</select></label>
    <label className="grid gap-2 text-sm font-semibold">Tutor<select aria-label="Tutor selection" name="tutor_id" required className="rounded-xl border p-3 font-normal"><option value="">Select a compatible Tutor</option>{compatibleTutors.map((x) => <option key={x.id} value={x.id}>{x.label}</option>)}</select></label>
    <label className="grid gap-2 text-sm font-semibold">Subject (optional)<select name="subject_id" className="rounded-xl border p-3 font-normal"><option value="">General tutoring</option>{subjects.map((x) => <option key={x.id} value={x.id}>{x.label}</option>)}</select></label>
    <div className="grid gap-4 sm:grid-cols-2"><label className="grid gap-2 text-sm font-semibold">Starts<input name="start_time" type="datetime-local" required className="rounded-xl border p-3 font-normal" /></label><label className="grid gap-2 text-sm font-semibold">Ends<input name="end_time" type="datetime-local" required className="rounded-xl border p-3 font-normal" /></label></div>
    <label className="grid gap-2 text-sm font-semibold">Meeting link (optional)<input name="zoom_link" type="url" className="rounded-xl border p-3 font-normal" /></label>
    <Submit disabled={unavailable} />
  </form>;
}
