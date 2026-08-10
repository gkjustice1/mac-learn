import { updatePassword } from "./actions";

type UpdatePasswordPageProps = {
  searchParams: Promise<{
    error?: string;
  }>;
};

export default async function UpdatePasswordPage({
  searchParams,
}: UpdatePasswordPageProps) {
  const { error } = await searchParams;

  const errorMessage =
    error === "missing_password"
      ? "Please enter and confirm your new password."
      : error === "password_mismatch"
        ? "The passwords do not match."
        : error === "password_update_failed"
          ? "We could not update your password. Please request a new recovery link."
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

          <h1 style={{ margin: 0 }}>Set a new password</h1>

          <p style={{ marginTop: "0.5rem" }}>
            Enter and confirm your new MAC Learn password.
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
        </div>

        <form action={updatePassword} style={{ display: "grid", gap: "1rem" }}>
          <label style={{ display: "grid", gap: "0.4rem" }}>
            <span>New password</span>
            <input
              type="password"
              name="password"
              autoComplete="new-password"
              required
              style={{ padding: "0.75rem" }}
            />
          </label>

          <label style={{ display: "grid", gap: "0.4rem" }}>
            <span>Confirm new password</span>
            <input
              type="password"
              name="confirmPassword"
              autoComplete="new-password"
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
            Update password
          </button>
        </form>
      </section>
    </main>
  );
}