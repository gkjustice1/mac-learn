import { redirect } from "next/navigation";

import { getAuthorizationContext } from "@/lib/auth/context";

export default async function DashboardPage() {
  const context = await getAuthorizationContext();
  const primaryAssignment = context.roles[0];

  if (!primaryAssignment) {
    redirect("/unauthorized");
  }

  switch (primaryAssignment.role) {
    case "platform_admin":
      redirect("/platform");

    case "organization_admin":
      if (primaryAssignment.organizationId) {
        redirect(
          `/organizations/${primaryAssignment.organizationId}`
        );
      }
      break;

    case "site_admin":
      if (
        primaryAssignment.organizationId &&
        primaryAssignment.siteId
      ) {
        redirect(
          `/organizations/${primaryAssignment.organizationId}/sites/${primaryAssignment.siteId}`
        );
      }
      break;
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