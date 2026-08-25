import "server-only";

import { createClient } from "@supabase/supabase-js";

function getSupabaseAdminEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secretKey =
    process.env.SUPABASE_SECRET_KEY ??
    process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url) {
    throw new Error(
      "Missing NEXT_PUBLIC_SUPABASE_URL environment variable."
    );
  }

  if (!secretKey) {
    throw new Error(
      "Missing SUPABASE_SECRET_KEY environment variable (or legacy SUPABASE_SERVICE_ROLE_KEY)."
    );
  }

  return { url, secretKey };
}

export function createAdminClient() {
  const { url, secretKey } = getSupabaseAdminEnv();

  return createClient(url, secretKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
}
