import { requireOrganizationAdmin } from "@/lib/auth/authorization";

type OrganizationPageProps = {
  params: Promise<{
    organizationId: string;
  }>;
};

export default async function OrganizationPage({
  params,
}: OrganizationPageProps) {
  const { organizationId } = await params;

  await requireOrganizationAdmin(organizationId);

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

        <h1 style={{ margin: 0 }}>Organization administration</h1>

        <p style={{ margin: 0 }}>
          Your account is authorized to administer this organization.
        </p>

        <p style={{ margin: 0 }}>
          Organization ID: {organizationId}
        </p>
      </section>
    </main>
  );
}