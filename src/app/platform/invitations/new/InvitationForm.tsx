"use client";

import Link from "next/link";
import { useActionState, useEffect, useState } from "react";
import { useFormStatus } from "react-dom";

import {
  provisionInvitation,
  type RoleAssignmentSearchKind,
  type RoleAssignmentSearchOption,
  searchRoleAssignmentOptions,
} from "@/app/actions";

const ROLE_OPTIONS = [
  { value: "student", label: "Student" },
  { value: "guardian", label: "Guardian" },
  { value: "tutor", label: "Tutor" },
  { value: "teacher", label: "Teacher" },
  { value: "academic_lead", label: "Academic Lead" },
] as const;

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
    >
      {pending ? "Sending invitation..." : "Send invitation"}
    </button>
  );
}

type ScopeSearchFieldProps = {
  disabled?: boolean;
  kind: Extract<RoleAssignmentSearchKind, "organization" | "site">;
  label: string;
  name: string;
  onChange: (value: string) => void;
  organizationId?: string | null;
  placeholder: string;
  required?: boolean;
  value: string;
};

function ScopeSearchField({
  disabled = false,
  kind,
  label,
  name,
  onChange,
  organizationId = null,
  placeholder,
  required = false,
  value,
}: ScopeSearchFieldProps) {
  const [query, setQuery] = useState("");
  const [options, setOptions] = useState<RoleAssignmentSearchOption[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (disabled || query.trim().length < 2) {
      return;
    }

    let cancelled = false;
    const timeout = window.setTimeout(async () => {
      setLoading(true);
      const result = await searchRoleAssignmentOptions(
        kind,
        query,
        organizationId
      );

      if (!cancelled) {
        setOptions(result.options);
        setError(result.error);
        setLoading(false);
      }
    }, 300);

    return () => {
      cancelled = true;
      window.clearTimeout(timeout);
    };
  }, [disabled, kind, organizationId, query]);

  return (
    <div className="grid gap-2">
      <label
        htmlFor={`${name}_search`}
        className="text-sm font-semibold text-slate-800"
      >
        {label}
      </label>
      <input
        id={`${name}_search`}
        type="search"
        value={query}
        disabled={disabled}
        onChange={(event) => {
          setQuery(event.target.value);
          onChange("");

          if (event.target.value.trim().length < 2) {
            setOptions([]);
            setError(null);
            setLoading(false);
          }
        }}
        placeholder={placeholder}
        autoComplete="off"
        className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm font-normal text-slate-950 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500"
      />
      <select
        id={name}
        name={name}
        aria-label={`${label} selection`}
        value={value}
        required={required}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
        className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm font-normal text-slate-950 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500"
      >
        <option value="">
          {disabled ? "Select required scope first" : "Select from search results"}
        </option>
        {options.map((option) => (
          <option key={option.id} value={option.id}>
            {option.label}
          </option>
        ))}
      </select>
      <p className="text-xs leading-5 text-slate-500">
        {loading
          ? "Searching..."
          : "Enter at least two characters. Results are limited to 20."}
      </p>
      {error ? (
        <p role="alert" className="text-xs text-red-700">
          Search failed: {error}
        </p>
      ) : null}
    </div>
  );
}

export function InvitationForm() {
  const [state, formAction] = useActionState(provisionInvitation, {
    error: null,
    invited: false,
  });
  const [organizationId, setOrganizationId] = useState("");
  const [roleKey, setRoleKey] = useState("");
  const [siteId, setSiteId] = useState("");
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");

  const isOrganizationScoped = roleKey === "academic_lead";

  if (state.invited) {
    return (
      <section className="grid gap-5 rounded-2xl border border-emerald-200 bg-emerald-50 p-6">
        <div>
          <h3 className="text-lg font-bold text-emerald-950">
            Invitation sent
          </h3>
          <p className="mt-2 text-sm leading-6 text-emerald-900">
            The enterprise identity remains invited until the recipient creates
            a password from the email link.
          </p>
        </div>

        <Link
          href="/platform/access-roles"
          className="w-fit text-sm font-semibold text-emerald-950 underline"
        >
          Return to Access &amp; Roles
        </Link>
      </section>
    );
  }

  return (
    <form action={formAction} className="grid gap-6">
      {state.error ? (
        <div
          role="alert"
          className="rounded-xl border border-red-200 bg-red-50 px-5 py-4 text-sm font-semibold text-red-900"
        >
          {state.error}
        </div>
      ) : null}

      <div className="grid gap-5 sm:grid-cols-2">
        <label className="grid gap-2 text-sm font-semibold text-slate-800">
          First name
          <input
            name="first_name"
            required
            value={firstName}
            onChange={(event) => setFirstName(event.target.value)}
            autoComplete="given-name"
            className="rounded-xl border border-slate-300 px-4 py-3 font-normal text-slate-950"
          />
        </label>

        <label className="grid gap-2 text-sm font-semibold text-slate-800">
          Last name
          <input
            name="last_name"
            required
            value={lastName}
            onChange={(event) => setLastName(event.target.value)}
            autoComplete="family-name"
            className="rounded-xl border border-slate-300 px-4 py-3 font-normal text-slate-950"
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Email
        <input
          name="email"
          type="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          autoComplete="email"
          className="rounded-xl border border-slate-300 px-4 py-3 font-normal text-slate-950"
        />
      </label>

      <ScopeSearchField
        kind="organization"
        label="Organization"
        name="organization_id"
        value={organizationId}
        required
        placeholder="Search active organizations by name or slug"
        onChange={(value) => {
          setOrganizationId(value);
          setSiteId("");
        }}
      />

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Role
        <select
          name="role_key"
          required
          value={roleKey}
          onChange={(event) => {
            const nextRole = event.target.value;
            setRoleKey(nextRole);

            if (nextRole === "academic_lead") {
              setSiteId("");
            }
          }}
          className="rounded-xl border border-slate-300 bg-white px-4 py-3 font-normal text-slate-950"
        >
          <option value="">Select a permitted role</option>
          {ROLE_OPTIONS.map((role) => (
            <option key={role.value} value={role.value}>
              {role.label}
            </option>
          ))}
        </select>
      </label>

      <ScopeSearchField
        kind="site"
        label="Site (optional)"
        name="site_id"
        value={siteId}
        organizationId={organizationId}
        disabled={!organizationId || isOrganizationScoped}
        placeholder="Search active sites by name or code"
        onChange={setSiteId}
      />

      <aside className="rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm leading-6 text-amber-950">
        The recipient will remain in invited status until password creation
        succeeds. Platform, organization, and site administrator roles cannot
        be granted through this invitation form.
      </aside>

      <div className="flex flex-wrap justify-end gap-3">
        <Link
          href="/platform/access-roles"
          className="rounded-xl border border-slate-300 px-5 py-3 text-sm font-semibold text-slate-800 hover:bg-slate-50"
        >
          Cancel
        </Link>
        <SubmitButton />
      </div>
    </form>
  );
}
