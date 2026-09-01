"use client";

import Link from "next/link";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { inviteExistingStudentLogin } from "../../actions";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} className="rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white disabled:opacity-60">{pending ? "Sending invitation..." : "Send Student invitation"}</button>;
}

export function StudentLoginInvitationForm({ studentId }: { studentId: string }) {
  const [state, action] = useActionState(inviteExistingStudentLogin, { invited: false, error: null });
  if (state.invited) return <div className="grid gap-4 rounded-xl border border-emerald-200 bg-emerald-50 p-5"><h3 className="font-bold text-emerald-950">Student invitation sent</h3><p className="text-sm text-emerald-900">The existing enrollment is linked to the invited Student login. The student must create a password from the newest invitation email.</p><Link href="/platform/students" className="font-semibold underline">Back to Students</Link></div>;
  return <form action={action} className="grid gap-5">
    <input type="hidden" name="student_id" value={studentId} />
    {state.error ? <div role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-semibold text-red-900">{state.error}</div> : null}
    <label className="grid gap-2 text-sm font-semibold text-slate-800">Student email
      <input name="email" type="email" required autoComplete="email" className="rounded-xl border border-slate-300 px-4 py-3 font-normal" />
    </label>
    <aside className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-950">This sends a real invitation and grants Student access only to this enrollment’s organization and primary site. Verify the email before sending.</aside>
    <div className="flex justify-end gap-3"><Link href="/platform/students" className="rounded-xl border border-slate-300 px-5 py-3 text-sm font-semibold">Cancel</Link><SubmitButton /></div>
  </form>;
}
