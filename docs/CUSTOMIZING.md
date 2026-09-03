# CUSTOMIZING.md

How to clone this template, adapt it to a real project, and swap any default. Every default in
`SPEC.md` §2 is trocável (swappable) — this file is where "trocável" becomes concrete steps.

## 1. Clone and rebrand

```bash
git clone <this-repo> my-project && cd my-project
rm -rf .git && git init && git branch -m main
rm -rf research/ docs/DECISIONS.md   # artifacts of generating THIS template, not your project
```

Edit the mission line at the top of `CLAUDE.md`. Delete `specs/example-feature/` and the
`SubscribeDialog`/`queries`/`handlers` example code once you've read it and understood the
pattern — it exists to prove the harness works, not to ship in your product.

## 2. Swap a stack layer

Each swap below: remove the old dependency, install the new one, update the one skill file
that documents the convention, re-run `pnpm verify`.

| Layer             | From → To                                                                                                                                           | What changes                                                                                                                                                                                                                                                                                                                     |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Components        | Radix → Base UI                                                                                                                                     | Once `npm view @base-ui-components/react dist-tags` shows a real `1.0.0` (ADR-006 amendment), swap the `@radix-ui/react-*` imports in `src/components/**` for `@base-ui-components/react` equivalents. Update `.claude/skills/component-conventions/SKILL.md`'s "Upgrade path" note. No file structure change needed.            |
| Lint              | ESLint+Prettier → Oxlint+Prettier                                                                                                                   | `pnpm remove eslint eslint-config-prettier eslint-plugin-jsx-a11y eslint-plugin-react-hooks eslint-plugin-react-refresh typescript-eslint @eslint/js globals`, `pnpm add -D oxlint`, replace `eslint.config.js` with `.oxlintrc.json`, update the `lint`/`lint:fix` scripts in `package.json` and step 2 of `scripts/verify.sh`. |
| Validation        | Zod → Arktype                                                                                                                                       | `pnpm remove zod && pnpm add arktype`, rewrite `src/lib/schemas.ts` with Arktype's type syntax. Both implement Standard Schema, so `routing-tanstack-router`'s search-param validation needs no change.                                                                                                                          |
| API codegen       | Hand-written MSW → Orval                                                                                                                            | Once there's a real OpenAPI spec, follow `.claude/skills/openapi-codegen/SKILL.md` (manual-invocation only — it does nothing until you ask for it).                                                                                                                                                                              |
| Core UI           | React → Vue or Svelte                                                                                                                               | Not a single-file swap — this is a preset-level change. Re-run the roadmap in `SPEC.md` §12 items 3-11 against the new framework's equivalents of TanStack Router/Query (both have Vue adapters), keep the harness (`.claude/`, `scripts/verify.sh` shape, hooks) unchanged.                                                     |
| Package manager   | pnpm → npm/yarn                                                                                                                                     | Already supported without changes — see §5 below.                                                                                                                                                                                                                                                                                |
| Storybook → Ladle | `pnpm remove storybook @storybook/react-vite && pnpm add -D ladle`, replace `.storybook/` config, update the `storybook`/`build-storybook` scripts. |

## 3. Add a skill

Create `.claude/skills/<name>/SKILL.md` with at minimum a `name` and `description` in
frontmatter. Add `paths: ["glob/**"]` if it should auto-load for specific files, or
`user-invocable: true` if it should be a new slash-command. Run `pnpm gen-hooks` afterward if
it's a command — that regenerates its `.github/prompts/<name>.prompt.md` mirror.

## 4. Add a subagent

Create `.claude/agents/<name>.md` with `name`, `description`, minimal `tools`, and an explicit
`model`. **Do not add `Agent` to `tools`** unless you have deliberately decided to allow
nesting beyond depth 1 — that decision should be its own ADR in your project, because it
breaks the Copilot-compatibility assumption documented in `docs/DECISIONS.md` ADR-003
(Copilot doesn't document configurable subagent nesting).

**First recommended extension, not a redesign:** if `reviewer` feels overloaded (mixing
quality, security, a11y cross-checks, and mutation-testing in one pass), split
`adversarial-reviewer` out as its own subagent focused only on the mutation-testing check in
`reviewer.md`'s rule 3. This was deliberately deferred in `docs/AGENT_ARCHITECTURE.md` §3.1 to
keep the initial roster small — it's the first place to grow, not the last.

## 5. Package manager: npm/yarn instead of pnpm

No `catalogs:` protocol and no pnpm-only script syntax are used anywhere in this template
(ADR-005), so:

```bash
rm pnpm-lock.yaml pnpm-workspace.yaml
npm install     # or: yarn install
```

`scripts/verify.sh` calls `pnpm exec <tool>` — change these to `npx <tool>` (npm) or just
`<tool>` (yarn, since yarn puts `.bin` on PATH inside scripts) if you fully switch. `pnpm verify`
in `package.json`'s `scripts.verify` becomes `npm run verify` / `yarn verify` regardless — the
script name doesn't change, only how you invoke it.

## 6. Adapt the gates

- **Add a pyramid step:** edit `scripts/verify.sh`'s `STEP_NAMES`/`STEP_CMDS` arrays and
  `count_failures_for_step`, keeping the `--json` output shape (`exit_code`, `failure_count`,
  `steps[]`) intact — `verify-gate.sh`'s ratchet depends on that shape.
- **Add/change a hook:** edit the referenced `.claude/hooks/*.sh` script for behavior changes,
  or `.claude/hooks/definitions.json` for event wiring changes, then run `pnpm gen-hooks` to
  regenerate the Copilot `.github/hooks/*.json` mirrors.
- **Change ratchet thresholds:** `MAX_ATTEMPTS` in `.claude/hooks/verify-gate.sh` (default 6,
  must stay below the Claude Code native Stop-hook block cap of 8 — see
  `research/FINDINGS.md` §2.1.4 — or raise `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` accordingly).

## 7. Token budgets

Per-role budgets live in `docs/AGENT_ARCHITECTURE.md` §3.5 as guidance, not enforced code —
they're a default trocável tuned for small tasks. If your project's tasks are larger, raise
them; there's no single file to edit, just the judgment you apply when a subagent's output
looks like it's running long.
