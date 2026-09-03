import { setupServer } from "msw/node";
import { handlers } from "./handlers";

/**
 * Node-side MSW server for Vitest. `onUnhandledRequest: "error"` is
 * deliberate — see .claude/skills/testing-rtl-msw/SKILL.md: a test that
 * reaches real network is a failing test, not a passing one.
 */
export const server = setupServer(...handlers);
