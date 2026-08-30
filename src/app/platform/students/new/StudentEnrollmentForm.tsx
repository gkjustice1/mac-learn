"use client";

import Link from "next/link";
import { useActionState, useEffect, useState } from "react";
import { useFormStatus } from "react-dom";

import {
  enrollStudent,
  searchEnrollmentOptions,
  type EnrollmentSearchOption,
} from "../actions";

type SearchFieldProps = {
  disabled?: boolean;
  kind: "organization" | "site" | "guardian";
  label: string;
  name: string;
  organizationId?: string | null;
  placeholder: string;
  required?: boolean;
  value: string;
  onChange: (value: string) => void;
};

function SearchField({
  disabled = false,
  kind,
  label,
  name,
  organizationId = null,
  placeholder,
  required = false,
  value,
  onChange,
}: SearchFieldProps) {
  const [query, setQuery] = useState("");
  const [options, setOptions] = useState<EnrollmentSearchOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (disabled || query.trim().length < 2) return;
    let cancelled = false;
    const timer = window.setTimeout(async () => {
      setLoading(true);
      const result = await searchEnrollmentOptions(kind, query, organizationId);
      if (!cancelled) {
        setOptions(result.options);
        setError(result.error);
        setLoading(false);
      }
    }, 300);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [disabled, kind, organizationId, query]);

  return (
    <div className="grid gap-2">
      <label htmlFor={`${name}_search`} className="text-sm font-semibold text-slate-800">
        {label}
      </label>
      <input
        id={`${name}_search`}
        type="search"
        value={query}
        disabled={disabled}
        placeholder={placeholder}
        autoComplete="off"
        onChange={(event) => {
          setQuery(event.target.value);
          onChange("");
          if (event.target.value.trim().length < 2) {
            setOptions([]);
            setError(null);
            setLoading(false);
          }
        }}
        className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-950 disabled:bg-slate-100"
      />
      <select
        id={name}
        name={name}
        aria-label={`${label} selection`}
        value={value}
        required={required}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
        className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-950 disabled:bg-slate-100"
      >
        <option value="">{disabled ? "Select the required scope first" : "Select from search results"}</option>
        {options.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}
      </select>
      <p className="text-xs text-slate-500">{loading ? "Searching..." : "Enter at least two characters."}</p>
      {error ? <p role="alert" className="text-xs text-red-700">Search failed: {error}</p> : null}
    </div>
  );
}

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white disabled:opacity-60"
    >
      {pending ? "Creating enrollment..." : "Create student enrollment"}
    </button>
  );
}

function currentLocalDate() {
  const now = new Date();
  const offset = now.getTimezoneOffset() * 60_000;
  return new Date(now.getTime() - offset).toISOString().slice(0, 10);
}

export function StudentEnrollmentForm() {
  const [state, formAction] = useActionState(enrollStudent, {
    enrolled: false,
    error: null,
    guardianInvited: false,
  });
  const [organizationId, setOrganizationId] = useState("");
  const [siteId, setSiteId] = useState("");
  const [guardianMode, setGuardianMode] = useState<"existing" | "new">("existing");
  const [guardianUserId, setGuardianUserId] = useState("");
  const [fields, setFields] = useState({
    first_name: "",
    last_name: "",
    grade_level: "",
    school_name: "",
    enrollment_start_date: currentLocalDate(),
    enterprise_status: "active",
    relationship_type: "parent_guardian",
    guardian_first_name: "",
    guardian_last_name: "",
    guardian_email: "",
  });
  const update = (name: keyof typeof fields, value: string) =>
    setFields((current) => ({ ...current, [name]: value }));

  if (state.enrolled) {
    return (
      <section className="grid gap-4 rounded-2xl border border-emerald-200 bg-emerald-50 p-6">
        <h3 className="text-lg font-bold text-emerald-950">Student enrollment created</h3>
        <p className="text-sm text-emerald-900">
          The student is linked to the guardian and is now available in Tutor operations.
          {state.guardianInvited ? " The new guardian must create a password from the invitation email." : ""}
        </p>
        <div className="flex flex-wrap gap-4">
          <Link href="/platform/tutor-operations" className="font-semibold underline">Open Tutor operations</Link>
          <Link href="/platform/students" className="font-semibold underline">View students</Link>
        </div>
      </section>
    );
  }

  return (
    <form action={formAction} className="grid gap-7">
      {state.error ? <div role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-semibold text-red-900">{state.error}</div> : null}

      <fieldset className="grid gap-5">
        <legend className="text-lg font-bold text-slate-950">Student information</legend>
        <div className="grid gap-5 sm:grid-cols-2">
          {([['first_name', 'First name'], ['last_name', 'Last name']] as const).map(([name, label]) => (
            <label key={name} className="grid gap-2 text-sm font-semibold text-slate-800">{label}
              <input name={name} required value={fields[name]} onChange={(e) => update(name, e.target.value)} autoComplete="off" className="rounded-xl border border-slate-300 px-4 py-3 font-normal" />
            </label>
          ))}
          <label className="grid gap-2 text-sm font-semibold text-slate-800">Grade level
            <input name="grade_level" required value={fields.grade_level} onChange={(e) => update('grade_level', e.target.value)} placeholder="Example: Grade 4" className="rounded-xl border border-slate-300 px-4 py-3 font-normal" />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-slate-800">School
            <input name="school_name" value={fields.school_name} onChange={(e) => update('school_name', e.target.value)} className="rounded-xl border border-slate-300 px-4 py-3 font-normal" />
          </label>
        </div>
      </fieldset>

      <fieldset className="grid gap-5">
        <legend className="text-lg font-bold text-slate-950">Enrollment</legend>
        <SearchField kind="organization" label="Organization" name="organization_id" value={organizationId} required placeholder="Search active organizations" onChange={(value) => { setOrganizationId(value); setSiteId(""); setGuardianUserId(""); }} />
        <SearchField kind="site" label="Primary site" name="site_id" organizationId={organizationId} disabled={!organizationId} value={siteId} required placeholder="Search active sites" onChange={(value) => { setSiteId(value); setGuardianUserId(""); }} />
        <div className="grid gap-5 sm:grid-cols-2">
          <label className="grid gap-2 text-sm font-semibold text-slate-800">Enrollment start date
            <input name="enrollment_start_date" type="date" required value={fields.enrollment_start_date} onChange={(e) => update('enrollment_start_date', e.target.value)} className="rounded-xl border border-slate-300 px-4 py-3 font-normal" />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-slate-800">Status
            <select name="enterprise_status" value={fields.enterprise_status} onChange={(e) => update('enterprise_status', e.target.value)} className="rounded-xl border border-slate-300 bg-white px-4 py-3 font-normal">
              <option value="active">Active</option><option value="inactive">Inactive</option>
            </select>
          </label>
        </div>
      </fieldset>

      <fieldset className="grid gap-5">
        <legend className="text-lg font-bold text-slate-950">Parent or guardian</legend>
        <div className="flex flex-wrap gap-6">
          <label className="flex items-center gap-2 text-sm font-semibold"><input type="radio" name="guardian_mode" value="existing" checked={guardianMode === 'existing'} onChange={() => { setGuardianMode('existing'); }} /> Existing guardian</label>
          <label className="flex items-center gap-2 text-sm font-semibold"><input type="radio" name="guardian_mode" value="new" checked={guardianMode === 'new'} onChange={() => { setGuardianMode('new'); setGuardianUserId(""); }} /> Invite new guardian</label>
        </div>
        {guardianMode === "existing" ? (
          <SearchField kind="guardian" label="Guardian" name="guardian_user_id" organizationId={organizationId} disabled={!organizationId || !siteId} value={guardianUserId} required placeholder="Search guardian name or email" onChange={setGuardianUserId} />
        ) : (
          <div className="grid gap-5 sm:grid-cols-2">
            <label className="grid gap-2 text-sm font-semibold">Guardian first name<input name="guardian_first_name" required value={fields.guardian_first_name} onChange={(e) => update('guardian_first_name', e.target.value)} className="rounded-xl border border-slate-300 px-4 py-3 font-normal" /></label>
            <label className="grid gap-2 text-sm font-semibold">Guardian last name<input name="guardian_last_name" required value={fields.guardian_last_name} onChange={(e) => update('guardian_last_name', e.target.value)} className="rounded-xl border border-slate-300 px-4 py-3 font-normal" /></label>
            <label className="grid gap-2 text-sm font-semibold sm:col-span-2">Guardian email<input name="guardian_email" type="email" required value={fields.guardian_email} onChange={(e) => update('guardian_email', e.target.value)} autoComplete="email" className="rounded-xl border border-slate-300 px-4 py-3 font-normal" /></label>
          </div>
        )}
        <label className="grid gap-2 text-sm font-semibold">Relationship
          <select name="relationship_type" value={fields.relationship_type} onChange={(e) => update('relationship_type', e.target.value)} className="rounded-xl border border-slate-300 bg-white px-4 py-3 font-normal">
            <option value="parent_guardian">Parent/guardian</option><option value="parent">Parent</option><option value="guardian">Legal guardian</option><option value="caregiver">Caregiver</option>
          </select>
        </label>
      </fieldset>

      <aside className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-950">This creates a real production student record and family linkage. Verify all information before submitting.</aside>
      <div className="flex justify-end gap-3"><Link href="/platform/students" className="rounded-xl border border-slate-300 px-5 py-3 text-sm font-semibold">Cancel</Link><SubmitButton /></div>
    </form>
  );
}
