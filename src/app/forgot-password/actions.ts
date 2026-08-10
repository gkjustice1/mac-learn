"use server";


import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export async function requestPasswordReset(formData: FormData) {
  const email = formData.get("email");

  if (typeof email !== "string" || !email) {
    redirect("/forgot-password?error=missing_email");
  }

const appUrl = process.env.NEXT_PUBLIC_APP_URL;

if (!appUrl) {
  redirect("/forgot-password?error=recovery_failed");
}
  const supabase = await createClient();

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${appUrl}/auth/callback`,
  });

  if (error) {
    const message = error.message.toLowerCase();

  if (message.includes("rate limit")) {
    redirect("/forgot-password?error=rate_limited");
  }

  redirect("/forgot-password?error=recovery_failed");
}

  redirect("/forgot-password?status=sent");
}