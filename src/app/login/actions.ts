"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export async function login(formData: FormData) {
  const email = formData.get("email");
  const password = formData.get("password");

  if (
    typeof email !== "string" ||
    typeof password !== "string" ||
    !email ||
    !password
  ) {
    redirect("/login?error=missing_credentials");
  }

  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    redirect("/login?error=invalid_credentials");
  }

  // A provisioned enterprise identity becomes active only after the invitee
  // has completed a successful authentication.
  if (data.user) {
    const { error: activationError } = await supabase.rpc(
      "mac_activate_invited_enterprise_user"
    );

    if (activationError) {
      await supabase.auth.signOut();
      redirect("/login?error=activation_failed");
    }
  }

  redirect("/dashboard");
}
