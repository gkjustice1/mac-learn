import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);

  const tokenHash = requestUrl.searchParams.get("token_hash");
  const type = requestUrl.searchParams.get("type") as EmailOtpType | null;

  if (!tokenHash || (type !== "recovery" && type !== "invite")) {
    return NextResponse.redirect(
      new URL("/login?error=recovery_failed", requestUrl.origin)
    );
  }

  const supabase = await createClient();

  const { error } = await supabase.auth.verifyOtp({
    token_hash: tokenHash,
    type,
  });

  if (error) {
    return NextResponse.redirect(
      new URL("/login?error=recovery_failed", requestUrl.origin)
    );
  }

  if (type === "invite") {
    const { data: activated, error: activationError } = await supabase.rpc(
      "mac_activate_invited_enterprise_user"
    );

    if (activationError || !activated) {
      await supabase.auth.signOut();
      return NextResponse.redirect(
        new URL("/login?error=activation_failed", requestUrl.origin)
      );
    }

    return NextResponse.redirect(
      new URL("/update-password?onboarding=invite", requestUrl.origin)
    );
  }

  return NextResponse.redirect(new URL("/update-password", requestUrl.origin));
}
