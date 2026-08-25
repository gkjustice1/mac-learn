"use client";

import Link from "next/link";
import { useActionState, useEffect, useState } from "react";
import { useFormStatus } from "react-dom";

import {
  createRoleAssignment,
  type RoleAssignmentSearchKind,
  type RoleAssignmentSearchOption,
  searchRoleAssignmentOptions,
} from "@/app/actions";

const ROLE_OPTIONS = [
  {
    value: "platform_admin",
    label: "Platform Admin",
    scope: "Platform-wide",
  },
  {
    value: "platform_support",
    label: "Platform Support",
    scope: "Platform-wide",
  },
  {
    value: "organization_admin",
    label: "Organization Admin",
    scope: "Organization required",
  },
  {
    value: "academic_lead",
    label: "Academic Lead",
    scope: "Organization required",
  },
  {
    value: "site_admin",
    label: "Site Admin",
    scope: "Organization and site required",
  },
  {
    value: "teacher",
    label: "Teacher",
    scope: "Organization required; site optional",
  },
  {
    value: "tutor",
    label: "Tutor",
    scope: "Organization required; site optional",
  },
  {
    value: "student",
    label: "Student",
    scope: "Organization required; site optional",
  },
  {
    value: "guardian",
    label: "Guardian",
    scope: "Organization required; site optional",
  },
] as const;

const PLATFORM_ROLES = new Set([
  "platform_admin",
  "platform_support",
]);

const ORGANIZATION_ONLY_ROLES = new Set([
  "organization_admin",
  "academic_lead",
]);

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
    >
      {pending ? "Creating..." : "Create role assignment"}
    </button>
  );
}

type SearchableOptionFieldProps = {
  disabled?: boolean;
  kind: RoleAssignmentSearchKind;
  label: string;
  name: string;
  onChange?: (value: string) => void;
  organizationId?: string | null;
  placeholder: string;
  required?: boolean;
  value: string;
};

function SearchableOptionField({
  disabled = false,
  kind,
  label,
  name,
  onChange,
  organizationId = null,
  placeholder,
  required = false,
  value,
}: SearchableOptionFieldProps) {
  const [query, setQuery] = useState("");
  const [options, setOptions] = useState<
    RoleAssignmentSearchOption[]
  >([]);
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
        setOptions((currentOptions) => {
          const selectedOption = currentOptions.find(
            (option) => option.id === value
          );

          if (
            selectedOption &&
            !result.options.some(
              (option) => option.id === selectedOption.id
            )
          ) {
            return [selectedOption, ...result.options];
          }

          return result.options;
        });
        setError(result.error);
        setLoading(false);
      }
    }, 300);

    return () => {
      cancelled = true;
      window.clearTimeout(timeout);
    };
  }, [disabled, kind, organizationId, query, value]);

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
          const nextQuery = event.target.value;

          setQuery(nextQuery);

          if (nextQuery.trim().length < 2) {
            setOptions([]);
            setError(null);
            setLoading(false);
          }
        }}
        placeholder={placeholder}
        autoComplete="off"
        className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-400"
      />

      <select
        id={name}
        name={name}
        value={value}
        required={required}
        disabled={disabled}
        onChange={(event) => onChange?.(event.target.value)}
        className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-400"
      >
        <option value="">
          {disabled
            ? `Select required scope first`
            : `Select from search results`}
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

export function RoleAssignmentForm() {
  const [state, formAction] = useActionState(
    createRoleAssignment,
    { error: null }
  );

  const [roleKey, setRoleKey] = useState("");
  const [userId, setUserId] = useState("");
  const [organizationId, setOrganizationId] = useState("");
  const [siteId, setSiteId] = useState("");

  const isPlatformRole = PLATFORM_ROLES.has(roleKey);

  const isOrganizationOnlyRole =
    ORGANIZATION_ONLY_ROLES.has(roleKey);

  const isSiteRequiredRole = roleKey === "site_admin";

  const organizationRequired =
    roleKey !== "" && !isPlatformRole;

  const siteEnabled =
    roleKey !== "" &&
    !isPlatformRole &&
    !isOrganizationOnlyRole &&
    organizationId !== "";

  function handleRoleChange(
    event: React.ChangeEvent<HTMLSelectElement>
  ) {
    const nextRole = event.target.value;

    setRoleKey(nextRole);

    if (PLATFORM_ROLES.has(nextRole)) {
      setOrganizationId("");
      setSiteId("");
    } else if (ORGANIZATION_ONLY_ROLES.has(nextRole)) {
      setSiteId("");
    }
  }

  return (
    <form action={formAction} className="grid gap-6">
      {state.error ? (
        <div
          role="alert"
          className="rounded-xl border border-red-200 bg-red-50 px-5 py-4"
        >
          <p className="text-sm font-semibold text-red-900">
            Role assignment could not be created.
          </p>

          <p className="mt-1 text-sm text-red-800">
            {state.error}
          </p>
        </div>
      ) : null}

      <SearchableOptionField
        kind="user"
        label="User"
        name="user_id"
        placeholder="Search active users by name, email, or UUID"
        required
        value={userId}
        onChange={setUserId}
      />

      <div className="grid gap-2">
        <label
          htmlFor="role_key"
          className="text-sm font-semibold text-slate-800"
        >
          Role
        </label>

        <select
          id="role_key"
          name="role_key"
          required
          value={roleKey}
          onChange={handleRoleChange}
          className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900"
        >
          <option value="" disabled>
            Select a MAC Learn role
          </option>

          {ROLE_OPTIONS.map((role) => (
            <option key={role.value} value={role.value}>
              {role.label} — {role.scope}
            </option>
          ))}
        </select>

        <p className="text-xs leading-5 text-slate-500">
          Select a role first. MAC Learn will adjust the available
          scope controls automatically.
        </p>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <SearchableOptionField
          kind="organization"
          label="Organization"
          name="organization_id"
          placeholder="Search active organizations by name or slug"
          required={organizationRequired}
          disabled={isPlatformRole || roleKey === ""}
          value={organizationId}
          onChange={(value) => {
            setOrganizationId(value);
            setSiteId("");
          }}
        />

        <SearchableOptionField
          kind="site"
          label="Site"
          name="site_id"
          placeholder="Search active sites by name or code"
          required={isSiteRequiredRole}
          disabled={!siteEnabled}
          organizationId={organizationId}
          value={siteId}
          onChange={setSiteId}
        />
      </div>

      <div className="rounded-xl border border-amber-200 bg-amber-50 p-4">
        <p className="text-sm font-semibold text-amber-900">
          Authorization scope is enforced on the server and in
          Supabase.
        </p>

        <p className="mt-1 text-xs leading-5 text-amber-800">
          Only active users, active organizations, and active sites
          may receive new assignments. Invalid role/scope
          combinations, mismatched organization/site selections, and
          duplicate active assignments will be rejected.
        </p>
      </div>

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Link
          href="/platform/access-roles"
          className="rounded-xl border border-slate-300 bg-white px-5 py-3 text-center text-sm font-semibold text-slate-700 hover:bg-slate-50"
        >
          Cancel
        </Link>

        <SubmitButton />
      </div>
    </form>
  );
}
