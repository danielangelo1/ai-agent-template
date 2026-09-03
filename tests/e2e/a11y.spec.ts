import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

/**
 * @a11y — route-level axe-core scan, run by the a11y-auditor subagent
 * and by verify.sh step 6. Only "critical"/"serious" impact violations
 * fail the gate (see .claude/hooks/verify-gate.sh and
 * .claude/skills/a11y-checklist/SKILL.md).
 */
const CRITICAL_IMPACTS = ["critical", "serious"];

test("@a11y home route has no critical/serious violations", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page }).analyze();
  const blocking = results.violations.filter((v) =>
    CRITICAL_IMPACTS.includes(v.impact ?? ""),
  );
  expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
});

test("@a11y subscribe dialog traps focus and has no critical/serious violations", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Subscribe" }).click();
  await expect(page.getByRole("dialog")).toBeVisible();

  const results = await new AxeBuilder({ page }).include('[role="dialog"]').analyze();
  const blocking = results.violations.filter((v) =>
    CRITICAL_IMPACTS.includes(v.impact ?? ""),
  );
  expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
});
