import { requireEnterpriseUser } from "@/lib/auth/authorization";

export default async function EnterprisePage() {
  await requireEnterpriseUser();

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

        <h1 style={{ margin: 0 }}>Enterprise access confirmed</h1>

        <p style={{ margin: 0 }}>
          Your authenticated account has an active enterprise authorization.
        </p>
      </section>
    </main>
  );
}