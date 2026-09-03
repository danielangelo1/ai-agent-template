import { test, expect } from "@playwright/test";

/**
 * @critical — the newsletter subscription flow is marked critical in
 * specs/example-feature/tasks.md (it is the only user-facing conversion
 * flow in the example app), so it must be covered end to end, not just
 * at the unit level. covers: EARS-1.
 */
test("@critical user can subscribe to the newsletter from the home page", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByTestId("subscriber-count")).toBeVisible();
  const before = await page.getByTestId("subscriber-count").textContent();

  await page.getByRole("button", { name: "Subscribe" }).click();
  await page.getByLabel("Email address").fill("critical-flow@example.com");
  await page.getByRole("button", { name: "Confirm" }).click();

  await expect(page.getByRole("dialog")).not.toBeVisible();
  await expect(page.getByTestId("subscriber-count")).not.toHaveText(before ?? "");
});
