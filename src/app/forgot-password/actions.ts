"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export async function requestPasswordReset(formData: FormData) {
  const email = formData.get("email");

  if (typeof email !== "string" || !email) {
    redirect("/forgot-password?error=missing_email");
  }

  const headerStore = await headers();
  const origin = headerStore.get("origin");

  if (!origin) {
    redirect("/forgot-password?error=recovery_failed");
  }

  const supabase = await createClient();

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${origin}/auth/callback`,
  });

  if (error) {
  console.error("Password recovery failed:", {
    message: error.message,
    status: error.status,
    code: error.code,
  });

  const message = error.message.toLowerCase();

  if (message.includes("rate limit")) {
    redirect("/forgot-password?error=rate_limited");
  }

  redirect("/forgot-password?error=recovery_failed");
}

  redirect("/forgot-password?status=sent");
}