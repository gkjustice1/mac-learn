"use client";

import { useActionState } from "react";

import {
  createTutorAvailability,
  createTutorProgressReport,
  createTutorSessionNote,
  type TutorActionState,
} from "./actions";

type Option = { id: string; label: string };
const initial: TutorActionState = { error: null, success: null };
function Message({ state }: { state: TutorActionState }) {
  return state.error ? (
    <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">
      {state.error}
    </p>
  ) : state.success ? (
    <p
      role="status"
      className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800"
    >
      {state.success}
    </p>
  ) : null;
}
const input = "rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm";
const button =
  "w-fit rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-50";

export function TutorOperationForms({
  students,
  sessions,
}: {
  students: Option[];
  sessions: Option[];
}) {
  const [availability, availabilityAction, availabilityPending] = useActionState(
    createTutorAvailability,
    initial,
  );
  const [note, noteAction, notePending] = useActionState(createTutorSessionNote, initial);
  const [report, reportAction, reportPending] = useActionState(
    createTutorProgressReport,
    initial,
  );
  return (
    <div className="grid gap-6">
      <form
        action={availabilityAction}
        className="grid gap-3 rounded-2xl border bg-white p-5 shadow-sm"
      >
        <h3 className="font-bold">Add availability</h3>
        <Message state={availability} />
        <div className="grid gap-3 sm:grid-cols-3">
          <label className="grid gap-1 text-sm font-semibold">
            Day
            <select name="day_of_week" className={input}>
              {[
                "Sunday",
                "Monday",
                "Tuesday",
                "Wednesday",
                "Thursday",
                "Friday",
                "Saturday",
              ].map((day, i) => (
                <option key={day} value={i}>
                  {day}
                </option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-sm font-semibold">
            Start
            <input required name="start_time" type="time" className={input} />
          </label>
          <label className="grid gap-1 text-sm font-semibold">
            End
            <input required name="end_time" type="time" className={input} />
          </label>
        </div>
        <button disabled={availabilityPending} className={button}>
          {availabilityPending ? "Adding…" : "Add availability"}
        </button>
      </form>
      <form
        action={noteAction}
        className="grid gap-3 rounded-2xl border bg-white p-5 shadow-sm"
      >
        <h3 className="font-bold">Create session note</h3>
        <Message state={note} />
        {sessions.length === 0 && !note.success && (
          <p className="text-sm text-amber-800">
            A scheduled session is required before adding a note.
          </p>
        )}
        <label className="grid gap-1 text-sm font-semibold">
          Session
          <select required name="session_id" className={input}>
            <option value="">Select session</option>
            {sessions.map((x) => (
              <option key={x.id} value={x.id}>
                {x.label}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm font-semibold">
          Attendance
          <select name="attendance_status" className={input}>
            {["present", "absent", "late", "excused"].map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
        </label>
        {[
          ["skills_covered", "Skills covered"],
          ["performance_notes", "Performance notes"],
          ["homework_assigned", "Homework assigned"],
          ["parent_summary", "Parent summary"],
        ].map(([name, label]) => (
          <label key={name} className="grid gap-1 text-sm font-semibold">
            {label}
            <textarea name={name} className={input} />
          </label>
        ))}
        <button disabled={!sessions.length || notePending} className={button}>
          {notePending ? "Saving…" : "Save session note"}
        </button>
      </form>
      <form
        action={reportAction}
        className="grid gap-3 rounded-2xl border bg-white p-5 shadow-sm"
      >
        <h3 className="font-bold">Create progress report</h3>
        <Message state={report} />
        {students.length === 0 && (
          <p className="text-sm text-amber-800">
            An assigned student is required before creating a report.
          </p>
        )}
        <label className="grid gap-1 text-sm font-semibold">
          Student
          <select required name="student_id" className={input}>
            <option value="">Select student</option>
            {students.map((x) => (
              <option key={x.id} value={x.id}>
                {x.label}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm font-semibold">
          Reporting period
          <input required name="reporting_period" className={input} />
        </label>
        {[
          ["strengths", "Strengths"],
          ["areas_for_improvement", "Areas for improvement"],
          ["skills_mastered", "Skills mastered"],
          ["next_goals", "Next goals"],
          ["comments", "Comments"],
        ].map(([name, label]) => (
          <label key={name} className="grid gap-1 text-sm font-semibold">
            {label}
            <textarea name={name} className={input} />
          </label>
        ))}
        <button disabled={!students.length || reportPending} className={button}>
          {reportPending ? "Creating…" : "Create progress report"}
        </button>
      </form>
    </div>
  );
}
