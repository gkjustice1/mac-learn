import Link from "next/link";
import type { ReactNode } from "react";

type AdminShellProps = {
  children: ReactNode;
  activeItem?: "dashboard" | "organizations" | "sites" | "access";

};

const navigation = [
  {
    key: "dashboard",
    label: "Dashboard",
    href: "/platform",
  },
  {
    key: "organizations",
    label: "Organizations",
    href: "/platform/organizations",
  },
  {
    key: "sites",
    label: "Sites",
    href: "/platform/sites",
  },
  {
    key: "access",
    label: "Access & Roles",
    href: "/platform/access-roles",
  },
] as const;

export function AdminShell({
  children,
  activeItem = "dashboard",
}: AdminShellProps) {

  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="grid min-h-screen lg:grid-cols-[260px_1fr]">
        <aside className="border-b border-mac-border bg-mac-surface lg:border-b-0 lg:border-r">
          <div className="flex h-full flex-col">
            <div className="border-b border-mac-border px-6 py-5">
              <div className="flex items-center gap-3">
                <div className="grid h-10 w-10 place-items-center rounded-xl bg-mac-accent text-sm font-black text-slate-950">
                  M
                </div>

                <div>
                  <p className="text-xs font-semibold tracking-[0.2em] text-mac-text-muted">
                    MAC LEARN
                  </p>
                  <h1 className="mt-1 text-lg font-bold text-mac-primary">
                    Administration
                  </h1>
                </div>
              </div>
            </div>

            <nav className="flex-1 px-4 py-5">
              <div className="grid gap-2">
                {navigation.map((item) => {
  const active = item.key === activeItem;

                  return (
                    <Link
                      key={item.label}
                      href={item.href}
                      className={
                        active
                          ? "rounded-xl bg-mac-primary px-4 py-3 text-sm font-semibold text-mac-primary-foreground shadow-sm"
                          : "rounded-xl px-4 py-3 text-sm font-medium text-slate-600 transition hover:bg-mac-surface-muted hover:text-mac-primary"
                      }
                    >
                      {item.label}
                    </Link>
                  );
                })}
              </div>
            </nav>

            <div className="border-t border-mac-border px-6 py-5">
              <div className="rounded-xl bg-mac-accent-soft p-4">
                <p className="text-xs font-bold uppercase tracking-[0.14em] text-lime-800">
                  Secure workspace
                </p>

                <p className="mt-1 text-xs leading-5 text-slate-600">
                  Access is controlled by your active MAC Learn role and scope.
                </p>
              </div>
            </div>
          </div>
        </aside>

        <div className="flex min-w-0 flex-col">
          <header className="border-b border-mac-border bg-mac-surface px-6 py-4">
            <div className="mx-auto flex max-w-7xl items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium text-mac-text-muted">
                  Platform Administration
                </p>

                <p className="text-lg font-semibold text-mac-primary">
                  MAC Learn
                </p>
              </div>

              <div className="flex items-center gap-3">
                <span className="hidden h-2.5 w-2.5 rounded-full bg-mac-accent sm:block" />

                <div className="rounded-full border border-mac-border bg-mac-surface-muted px-3 py-1 text-xs font-semibold text-slate-700">
                  Platform Admin
                </div>
              </div>
            </div>
          </header>

          <main className="flex-1 px-6 py-8">
            <div className="mx-auto w-full max-w-7xl">{children}</div>
          </main>
        </div>
      </div>
    </div>
  );
}
