"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export async function updatePassword(formData: FormData) {
  const password = formData.get("password");
  const confirmPassword = formData.get("confirmPassword");

  if (
    typeof password !== "string" ||
    typeof confirmPassword !== "string" ||
    !password ||
    !confirmPassword
  ) {
    redirect("/update-password?error=missing_password");
  }

  if (password !== confirmPassword) {
    redirect("/update-password?error=password_mismatch");
  }

  const supabase = await createClient();

const {
  data: { user },
  error: userError,
} = await supabase.auth.getUser();

if (userError || !user) {
  redirect("/login?error=recovery_failed");
}

const { error } = await supabase.auth.updateUser({
  password,
});

  if (error) {
    redirect("/update-password?error=password_update_failed");
  }

  redirect("/dashboard");
}