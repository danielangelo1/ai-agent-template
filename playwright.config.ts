import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? "dot" : "list",
  use: {
    baseURL: "http://localhost:4319",
    trace: "on-first-retry",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    // node_modules/.bin, not `pnpm exec` — portable across npm/yarn/pnpm
    // (ADR-005, scripts/verify.sh has the same convention and rationale).
    command: "node_modules/.bin/vite dev --port 4319 --strictPort",
    url: "http://localhost:4319",
    // Always start a fresh server for e2e — never silently reuse whatever
    // else happens to be bound to the port (determinism > convenience).
    reuseExistingServer: false,
    // Generous: a cold first run also pre-bundles deps and generates
    // routeTree.gen.ts, which can be slower than a plain server boot.
    timeout: 60_000,
  },
});
