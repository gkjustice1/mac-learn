import { requireSiteAdmin } from "@/lib/auth/authorization";

type SitePageProps = {
  params: Promise<{
    organizationId: string;
    siteId: string;
  }>;
};

export default async function SitePage({
  params,
}: SitePageProps) {
  const { organizationId, siteId } = await params;

  await requireSiteAdmin(organizationId, siteId);

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

        <h1 style={{ margin: 0 }}>Site administration</h1>

        <p style={{ margin: 0 }}>
          Your account is authorized to administer this site.
        </p>

        <p style={{ margin: 0 }}>
          Organization ID: {organizationId}
        </p>

        <p style={{ margin: 0 }}>
          Site ID: {siteId}
        </p>
      </section>
    </main>
  );
}