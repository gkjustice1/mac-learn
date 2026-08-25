"use client";

import { useActionState } from "react";

import { saveOrganizationConfiguration } from "@/app/actions";

type OrganizationConfigurationFormProps = {
  organizationId: string;
  defaultTimezone: string;
  defaultLocale: string;
  supportedLocales: string[];
  academicYearStartMonth: number;
  attendanceRequired: boolean;
};

const initialState = { error: null };

export function OrganizationConfigurationForm({
  organizationId,
  defaultTimezone,
  defaultLocale,
  supportedLocales,
  academicYearStartMonth,
  attendanceRequired,
}: OrganizationConfigurationFormProps) {
  const [state, formAction, pending] = useActionState(
    saveOrganizationConfiguration,
    initialState
  );

  return (
    <form action={formAction} className="grid gap-5">
      <input type="hidden" name="organization_id" value={organizationId} />

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Default timezone
        <input
          name="default_timezone"
          defaultValue={defaultTimezone}
          required
          maxLength={64}
          className="rounded-lg border border-slate-300 px-3 py-2 font-normal"
        />
        <span className="font-normal text-slate-500">
          Use an IANA timezone, such as America/New_York.
        </span>
      </label>

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Default locale
        <input
          name="default_locale"
          defaultValue={defaultLocale}
          required
          maxLength={64}
          className="rounded-lg border border-slate-300 px-3 py-2 font-normal"
        />
      </label>

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Supported locales
        <input
          name="supported_locales"
          defaultValue={supportedLocales.join(", ")}
          required
          maxLength={160}
          className="rounded-lg border border-slate-300 px-3 py-2 font-normal"
        />
        <span className="font-normal text-slate-500">
          Comma-separated BCP 47 locale tags, such as en-US, es-419, or zh-Hant-TW. The default locale must be included.
        </span>
      </label>

      <label className="grid gap-2 text-sm font-semibold text-slate-800">
        Academic-year start month
        <select
          name="academic_year_start_month"
          defaultValue={String(academicYearStartMonth)}
          className="rounded-lg border border-slate-300 px-3 py-2 font-normal"
        >
          {Array.from({ length: 12 }, (_, index) => index + 1).map((month) => (
            <option key={month} value={month}>
              {new Date(2026, month - 1, 1).toLocaleString("en-US", {
                month: "long",
              })}
            </option>
          ))}
        </select>
      </label>

      <label className="flex items-center gap-3 text-sm font-semibold text-slate-800">
        <input
          name="attendance_required"
          type="checkbox"
          defaultChecked={attendanceRequired}
          className="h-4 w-4"
        />
        Require attendance tracking by default
      </label>

      {state.error ? (
        <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700">
          {state.error}
        </p>
      ) : null}

      <div>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-slate-950 px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
        >
          {pending ? "Saving…" : "Save configuration"}
        </button>
      </div>
    </form>
  );
}
