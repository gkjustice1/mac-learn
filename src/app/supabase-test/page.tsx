import { createClient } from "@/lib/supabase/server";

export default async function SupabaseTestPage() {
  const supabase = await createClient();

  const { data, error } = await supabase.auth.getUser();

  return (
    <main style={{ padding: "2rem", fontFamily: "Arial, sans-serif" }}>
      <h1>MAC LEARN Supabase Test</h1>

      <p>
        Supabase client initialized successfully.
      </p>

      <p>
        Auth status: {error ? "Not authenticated / connection reached" : "Authenticated"}
      </p>

      <pre>
        {JSON.stringify(
          {
            user: data?.user?.id ?? null,
            error: error?.message ?? null,
          },
          null,
          2
        )}
      </pre>
    </main>
  );
}