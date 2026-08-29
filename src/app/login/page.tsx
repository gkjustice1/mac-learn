import { login } from "./actions";

type LoginPageProps = {
  searchParams: Promise<{
    error?: string;
  }>;
};

export default async function LoginPage({
  searchParams,
}: LoginPageProps) {
  const { error } = await searchParams;

  const errorMessage =
    error === "missing_credentials"
      ? "Please enter both your email and password."
      : error === "invalid_credentials"
        ? "The email or password you entered is incorrect."
        : error === "activation_failed"
          ? "Your account could not be activated. Please contact MAC Learn support."
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

{errorMessage && (
  <p
    role="alert"
    style={{
      marginTop: "0.75rem",
      padding: "0.75rem",
      border: "1px solid currentColor",
    }}
  >
    {errorMessage}
  </p>
)}

          <h1 style={{ margin: 0 }}>Sign in</h1>

          <p style={{ marginTop: "0.5rem" }}>
            Access your MAC Learn account.
          </p>
        </div>

        <form action={login} style={{ display: "grid", gap: "1rem" }}>
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

          <label style={{ display: "grid", gap: "0.4rem" }}>
            <span>Password</span>
            <input
              type="password"
              name="password"
              autoComplete="current-password"
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
            Sign in
          </button>
        </form>

<p style={{ marginTop: "0.5rem" }}>
  <a href="/forgot-password">
    Forgot password?
  </a>
</p>
      </section>
    </main>
  );
}
