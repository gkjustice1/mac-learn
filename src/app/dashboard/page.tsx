import { redirect } from "next/navigation";

import { getAuthorizationContext } from "@/lib/auth/context";
import { resolveWorkspacePath } from "@/lib/auth/workspace";

export default async function DashboardPage() {
  const context = await getAuthorizationContext();
  const primaryAssignment = context.roles[0];

  if (!primaryAssignment) {
    redirect("/unauthorized");
  }

  const workspacePath = resolveWorkspacePath(primaryAssignment);

  if (workspacePath) {
    redirect(workspacePath);
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: "2rem",
        fontFamily: "Arial, sans-serif",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: "640px",
          display: "grid",
          gap: "1rem",
          textAlign: "center",
        }}
      >
        <p style={{ margin: 0, fontWeight: 700 }}>MAC LEARN</p>

        <h1 style={{ margin: 0 }}>Dashboard</h1>

        <p style={{ margin: 0 }}>
          Signed in as {context.primaryRole ?? "MAC Learn user"}.
        </p>

        <p style={{ margin: 0 }}>
          Your role-specific workspace is being prepared.
        </p>
      </section>
    </main>
  );
}
