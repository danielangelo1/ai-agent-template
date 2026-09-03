import { createRootRoute, Link, Outlet } from "@tanstack/react-router";

export const Route = createRootRoute({
  component: RootLayout,
});

function RootLayout() {
  return (
    <div className="mx-auto max-w-2xl p-6">
      <nav className="mb-6 flex gap-4 text-sm font-medium text-brand-700">
        <Link to="/" activeProps={{ className: "underline" }}>
          Home
        </Link>
        <Link to="/about" activeProps={{ className: "underline" }}>
          About
        </Link>
      </nav>
      <Outlet />
    </div>
  );
}
