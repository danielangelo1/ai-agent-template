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
    command: "pnpm exec vite dev --port 4319 --strictPort",
    url: "http://localhost:4319",
    // Always start a fresh server for e2e — never silently reuse whatever
    // else happens to be bound to the port (determinism > convenience).
    reuseExistingServer: false,
    timeout: 30_000,
  },
});
