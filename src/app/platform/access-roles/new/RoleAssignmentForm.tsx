"use client";

import Link from "next/link";
import { useActionState, useMemo, useState } from "react";
import { useFormStatus } from "react-dom";

import { createRoleAssignment } from "@/app/actions";

type UserOption = {
  id: string;
  label: string;
};

type OrganizationOption = {
  id: string;
  label: string;
};

type SiteOption = {
  id: string;
  label: string;
  organizationId: string;
};

type RoleAssignmentFormProps = {
  users: UserOption[];
  organizations: OrganizationOption[];
  sites: SiteOption[];
};

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

export function RoleAssignmentForm({
  users,
  organizations,
  sites,
}: RoleAssignmentFormProps) {
  const [state, formAction] = useActionState(
    createRoleAssignment,
    { error: null }
  );

  const [roleKey, setRoleKey] = useState("");
  const [organizationId, setOrganizationId] = useState("");

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

  const filteredSites = useMemo(
    () =>
      sites.filter(
        (site) => site.organizationId === organizationId
      ),
    [organizationId, sites]
  );

  function handleRoleChange(
    event: React.ChangeEvent<HTMLSelectElement>
  ) {
    const nextRole = event.target.value;

    setRoleKey(nextRole);

    if (PLATFORM_ROLES.has(nextRole)) {
      setOrganizationId("");
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

      <div className="grid gap-2">
        <label
          htmlFor="user_id"
          className="text-sm font-semibold text-slate-800"
        >
          User
        </label>

        <select
          id="user_id"
          name="user_id"
          required
          defaultValue=""
          className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900"
        >
          <option value="" disabled>
            Select an active user
          </option>

          {users.map((user) => (
            <option key={user.id} value={user.id}>
              {user.label}
            </option>
          ))}
        </select>

        <p className="text-xs leading-5 text-slate-500">
          Only users with an active enterprise account are available.
        </p>
      </div>

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
        <div className="grid gap-2">
          <label
            htmlFor="organization_id"
            className="text-sm font-semibold text-slate-800"
          >
            Organization
          </label>

          <select
            id="organization_id"
            name="organization_id"
            required={organizationRequired}
            disabled={isPlatformRole || roleKey === ""}
            value={organizationId}
            onChange={(event) =>
              setOrganizationId(event.target.value)
            }
            className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-400"
          >
            <option value="">
              {organizationRequired
                ? "Select an organization"
                : "No organization"}
            </option>

            {organizations.map((organization) => (
              <option
                key={organization.id}
                value={organization.id}
              >
                {organization.label}
              </option>
            ))}
          </select>
        </div>

        <div className="grid gap-2">
          <label
            htmlFor="site_id"
            className="text-sm font-semibold text-slate-800"
          >
            Site
          </label>

          <select
            id="site_id"
            name="site_id"
            required={isSiteRequiredRole}
            disabled={!siteEnabled}
            defaultValue=""
            key={`${roleKey}-${organizationId}`}
            className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-400"
          >
            <option value="">
              {isSiteRequiredRole
                ? "Select a site"
                : "No site"}
            </option>

            {filteredSites.map((site) => (
              <option key={site.id} value={site.id}>
                {site.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="grid gap-2">
        <label
          htmlFor="valid_until"
          className="text-sm font-semibold text-slate-800"
        >
          Expiration
        </label>

        <input
          id="valid_until"
          name="valid_until"
          type="datetime-local"
          className="rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm text-slate-900"
        />

        <p className="text-xs leading-5 text-slate-500">
          Optional. Leave blank for no expiration. The assignment
          starts immediately when created.
        </p>
      </div>

      <div className="rounded-xl border border-amber-200 bg-amber-50 p-4">
        <p className="text-sm font-semibold text-amber-900">
          Authorization scope is enforced on the server and in
          Supabase.
        </p>

        <p className="mt-1 text-xs leading-5 text-amber-800">
          Invalid role/scope combinations, mismatched
          organization/site selections, inactive users, and
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