#!/usr/bin/env node
// scripts/gen-hooks.mjs — generates the Copilot adapter surface from the
// Claude Code sources: .github/hooks/*.json from .claude/hooks/definitions.json,
// and .github/prompts/*.prompt.md from each command-flavored .claude/skills/*/SKILL.md.
// ADR-001 / SPEC.md §5. Re-run after editing hooks/definitions.json or a
// command skill's frontmatter/body.
//
// Usage: node scripts/gen-hooks.mjs   (or: pnpm gen-hooks)

import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from "node:fs";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "..");

function genHooks() {
  const defsPath = path.join(ROOT, ".claude/hooks/definitions.json");
  const { hooks } = JSON.parse(readFileSync(defsPath, "utf8"));
  const outDir = path.join(ROOT, ".github/hooks");
  mkdirSync(outDir, { recursive: true });

  const byEvent = {};
  for (const h of hooks) {
    byEvent[h.copilotEvent] ??= [];
    byEvent[h.copilotEvent].push({
      script: h.script,
      blocking: h.blocking,
      description: h.description,
    });
  }

  for (const [event, entries] of Object.entries(byEvent)) {
    const outPath = path.join(outDir, `${event}.json`);
    writeFileSync(
      outPath,
      JSON.stringify(
        {
          $generated_by:
            "scripts/gen-hooks.mjs — do not edit by hand, edit .claude/hooks/definitions.json instead",
          event,
          hooks: entries,
        },
        null,
        2,
      ) + "\n",
    );
    console.log(`wrote ${path.relative(ROOT, outPath)}`);
  }
}

function parseFrontmatter(raw) {
  const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, body: raw };
  const [, fmBlock, body] = match;
  const frontmatter = {};
  for (const line of fmBlock.split("\n")) {
    const m = line.match(/^([a-zA-Z-]+):\s*(.*)$/);
    if (m) frontmatter[m[1]] = m[2].replace(/^"(.*)"$/, "$1");
  }
  return { frontmatter, body };
}

function genPrompts() {
  const skillsDir = path.join(ROOT, ".claude/skills");
  const outDir = path.join(ROOT, ".github/prompts");
  mkdirSync(outDir, { recursive: true });

  if (!existsSync(skillsDir)) return;

  for (const name of readdirSync(skillsDir)) {
    const skillPath = path.join(skillsDir, name, "SKILL.md");
    if (!existsSync(skillPath)) continue;

    const raw = readFileSync(skillPath, "utf8");
    const { frontmatter, body } = parseFrontmatter(raw);
    if (frontmatter["user-invocable"] === "false") continue;
    // Only commands are mirrored as prompt files — expertise-only skills
    // (no explicit "user-invocable: true") stay Claude-Code-only, since
    // Copilot prompt files are inherently manually-invoked (SPEC.md §5
    // synthesis table: Skills have no Copilot equivalent).
    if (frontmatter["user-invocable"] !== "true") continue;

    const description =
      frontmatter.description ?? `Run the /${name} step of the pipeline.`;
    const promptBody = [
      "---",
      `description: "${description}"`,
      "---",
      "",
      body.trim(),
      "",
    ].join("\n");

    const outPath = path.join(outDir, `${name}.prompt.md`);
    writeFileSync(outPath, promptBody);
    console.log(`wrote ${path.relative(ROOT, outPath)}`);
  }
}

genHooks();
genPrompts();
