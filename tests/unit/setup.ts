import "@testing-library/jest-dom/vitest";
import { afterAll, afterEach, beforeAll } from "vitest";
import { server } from "@/mocks/server";
import { resetSubscriberCount } from "@/mocks/handlers";

// onUnhandledRequest: "error" is deliberate — see .claude/skills/testing-rtl-msw.
// A test that reaches real network is a failing test, not a passing one.
beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => {
  server.resetHandlers();
  resetSubscriberCount();
});
afterAll(() => server.close());

if (!window.matchMedia) {
  window.matchMedia = (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  });
}
