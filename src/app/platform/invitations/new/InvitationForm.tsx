"use client";

import Link from "next/link";
import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";

import { provisionInvitation } from "@/app/actions";

type OrganizationOption = {
  id: string;
  name: string;
};

type SiteOption = {
  id: string;
  name: string;
  organizationId: string;
};

type InvitationFormProps = {
  organizations: OrganizationOption[];
  sites: SiteOption[];
};

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

export function InvitationForm({
  organizations,
  sites,
}: InvitationFormProps) {
  const [state, formAction] = useActionState(provisionInvitation, {
    error: null,
    invited: false,
  });
  const [organizationId, setOrganizationId] = useState("");
  const [roleKey, setRoleKey] = useState("");
  const [siteId, setSiteId] = useState("");

  const availableSites = sites.filter(
    (site) => site.organizationId === organizationId
  );
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
            autoComplete="given-name"
            className="rounded-xl border border-slate-300 px-4 py-3 font-normal text-slate-950"
          />
        </label>

        <label className="grid gap-2 text-sm font-semibold text-slate-800">
          Last name
          <input
            name="last_name"
            required
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
          autoComplete="email"
          className="rounded-xl border border-slate-300 px-4 py-3 font-normal text-slate-950"
        />
      </label>

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Organization
        <select
          name="organization_id"
          required
          value={organizationId}
          onChange={(event) => {
            setOrganizationId(event.target.value);
            setSiteId("");
          }}
          className="rounded-xl border border-slate-300 bg-white px-4 py-3 font-normal text-slate-950"
        >
          <option value="">Select an active organization</option>
          {organizations.map((organization) => (
            <option key={organization.id} value={organization.id}>
              {organization.name}
            </option>
          ))}
        </select>
      </label>

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

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Site <span className="font-normal text-slate-500">(optional)</span>
        <select
          name="site_id"
          value={siteId}
          disabled={!organizationId || isOrganizationScoped}
          onChange={(event) => setSiteId(event.target.value)}
          className="rounded-xl border border-slate-300 bg-white px-4 py-3 font-normal text-slate-950 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500"
        >
          <option value="">
            {isOrganizationScoped
              ? "Academic Lead is organization-scoped"
              : "No site restriction"}
          </option>
          {availableSites.map((site) => (
            <option key={site.id} value={site.id}>
              {site.name}
            </option>
          ))}
        </select>
      </label>

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
