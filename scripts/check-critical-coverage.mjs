#!/usr/bin/env node
// scripts/check-critical-coverage.mjs — SPEC.md §11, EARS-11: a task marked
// `critical: true` in any specs/*/tasks.md must have its referenced test
// file exist AND contain an `@critical` tag. Run as part of verify.sh's
// e2e step, before Playwright itself runs.

import { readFileSync, existsSync, readdirSync } from "node:fs";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "..");
const SPECS_DIR = path.join(ROOT, "specs");

function findTasksFiles() {
  if (!existsSync(SPECS_DIR)) return [];
  return readdirSync(SPECS_DIR)
    .map((d) => path.join(SPECS_DIR, d, "tasks.md"))
    .filter((p) => existsSync(p) && !p.includes("_TEMPLATE"));
}

function parseCriticalTasks(tasksMdPath) {
  const raw = readFileSync(tasksMdPath, "utf8");
  // Split into per-task blocks on lines starting with "- [ ]" or "- [x]".
  const blocks = raw.split(/\n(?=- \[[ x]\])/);
  const critical = [];
  for (const block of blocks) {
    if (!/critical:\s*true/i.test(block)) continue;
    const idMatch = block.match(/\*\*(T\d+)\*\*/);
    // A critical task's Test: line may name a unit test AND an e2e test
    // (see specs/example-feature/tasks.md) — collect every backtick-quoted
    // path on the Test: line, not just the first one, so the e2e path
    // isn't missed when a unit test is listed first.
    const testLine = block.match(/^\s*-\s*Test:.*$/m)?.[0] ?? "";
    const allPaths = [...testLine.matchAll(/`([^`]+)`/g)].map((m) => m[1]);
    const e2ePaths = allPaths.filter((p) => /^tests\/e2e\/.*\.spec\.ts$/.test(p));
    critical.push({
      id: idMatch?.[1] ?? "unknown",
      e2ePaths,
      source: tasksMdPath,
    });
  }
  return critical;
}

const violations = [];

for (const tasksFile of findTasksFiles()) {
  for (const task of parseCriticalTasks(tasksFile)) {
    if (task.e2ePaths.length === 0) {
      violations.push(
        `${path.relative(ROOT, task.source)} task ${task.id}: critical:true but its "Test:" line names no tests/e2e/*.spec.ts file.`,
      );
      continue;
    }

    const covered = task.e2ePaths.every((rel) => {
      const abs = path.join(ROOT, rel);
      return existsSync(abs) && readFileSync(abs, "utf8").includes("@critical");
    });

    if (!covered) {
      violations.push(
        `${path.relative(ROOT, task.source)} task ${task.id}: names ${task.e2ePaths.join(", ")} but the file is missing or has no @critical-tagged test.`,
      );
    }
  }
}

if (violations.length > 0) {
  console.error("Critical-coverage check failed (SPEC.md §11, EARS-11):");
  for (const v of violations) console.error(`  - ${v}`);
  process.exit(1);
}

console.log(`Critical-coverage check passed.`);
