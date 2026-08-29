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

  const { data: identity, error: identityError } = await supabase
    .from("users")
    .select("account_status")
    .eq("id", user.id)
    .maybeSingle();

  if (identityError) {
    redirect("/update-password?error=identity_lookup_failed");
  }

  const { error } = await supabase.auth.updateUser({
    password,
  });

  if (error) {
    redirect("/update-password?error=password_update_failed");
  }

  if (identity?.account_status === "invited") {
    const { data: activated, error: activationError } = await supabase.rpc(
      "mac_activate_invited_enterprise_user"
    );

    if (activationError || !activated) {
      await supabase.auth.signOut();
      redirect("/login?error=activation_failed");
    }
  }

  redirect("/dashboard");
}
