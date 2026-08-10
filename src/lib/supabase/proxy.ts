import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getSupabaseEnv } from "./env";

export async function updateSession(request: NextRequest) {
  const { url, publishableKey } = getSupabaseEnv();

  let response = NextResponse.next({
    request,
  });

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },

      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value);
        });

        response = NextResponse.next({
          request,
        });

        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const pathname = request.nextUrl.pathname;
 const isPublicAuthRoute =
  pathname === "/login" ||
  pathname === "/forgot-password" ||
  pathname === "/auth/callback";
  if (!user && !isPublicAuthRoute) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";

    return NextResponse.redirect(loginUrl);
  }

  if (user && pathname === "/login") {
    const homeUrl = request.nextUrl.clone();
    homeUrl.pathname = "/";

    return NextResponse.redirect(homeUrl);
  }

  return response;
}