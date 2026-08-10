import { requestPasswordReset } from "./actions";

type ForgotPasswordPageProps = {
  searchParams: Promise<{
    status?: string;
    error?: string;
  }>;
};

export default async function ForgotPasswordPage({
  searchParams,
}: ForgotPasswordPageProps) {
  const { status, error } = await searchParams;

  const message =
  status === "sent"
    ? "If an account exists for that email, a password recovery link has been sent."
    : error === "missing_email"
      ? "Please enter your email address."
      : error === "rate_limited"
        ? "Too many recovery emails have been requested. Please wait and try again later."
        : error === "recovery_failed"
          ? "We could not start password recovery. Please try again later."
          : null;

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
          maxWidth: "420px",
          display: "grid",
          gap: "1rem",
        }}
      >
        <div>
          <p style={{ marginBottom: "0.5rem", fontWeight: 700 }}>
            MAC LEARN
          </p>

          <h1 style={{ margin: 0 }}>Forgot password</h1>

          <p style={{ marginTop: "0.5rem" }}>
            Enter your email address to receive a password recovery link.
          </p>

          {message && (
            <p
              role="status"
              style={{
                marginTop: "0.75rem",
                padding: "0.75rem",
                border: "1px solid currentColor",
              }}
            >
              {message}
            </p>
          )}
        </div>

        <form
          action={requestPasswordReset}
          style={{ display: "grid", gap: "1rem" }}
        >
          <label style={{ display: "grid", gap: "0.4rem" }}>
            <span>Email</span>
            <input
              type="email"
              name="email"
              autoComplete="email"
              required
              style={{ padding: "0.75rem" }}
            />
          </label>

          <button
            type="submit"
            style={{
              padding: "0.8rem 1rem",
              cursor: "pointer",
              fontWeight: 700,
            }}
          >
            Send recovery link
          </button>
        </form>
      </section>
    </main>
  );
}
