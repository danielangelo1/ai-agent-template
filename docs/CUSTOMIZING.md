# CUSTOMIZING.md

How to clone this template, adapt it to a real project, and swap any default. Every default in
`SPEC.md` §2 is trocável (swappable) — this file is where "trocável" becomes concrete steps.

## 1. Clone and rebrand

```bash
git clone <this-repo> my-project && cd my-project
scripts/init.sh
```

`init.sh` asks for a project name and a one-line mission, then: removes `docs/meta/` (the
paper trail of how this template itself was generated — not your project's history), renames
the project in `package.json`/`README.md`/`CLAUDE.md`, and starts a fresh git history with one
initial commit. It's interactive by default; pass `--name`, `--description`, `--yes` to run
non-interactively. It refuses to run a second time (checks for `docs/meta/` as its own
"already initialized" signal) — if you need a true reset, remove `.git` yourself first.

Prefer to do it by hand, or `init.sh` doesn't fit your case? That's all it does:

```bash
rm -rf .git && git init && git branch -m main
rm -rf docs/meta/   # artifacts of generating THIS template, not your project
```

Then edit the mission line at the top of `CLAUDE.md` yourself.

Either way, delete `specs/example-feature/` and the `SubscribeDialog`/`queries`/`handlers`
example code once you've read it and understood the pattern — it exists to prove the harness
works, not to ship in your product. `init.sh` deliberately does not do this for you (it can't
know if you've read it yet).

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
breaks the Copilot-compatibility assumption this template is built on (Copilot doesn't
document configurable subagent nesting — see `docs/meta/DECISIONS.md` ADR-003 if still
present).

**First recommended extension, not a redesign:** if `reviewer` feels overloaded (mixing
quality, security, a11y cross-checks, and mutation-testing in one pass), split
`adversarial-reviewer` out as its own subagent focused only on the mutation-testing check in
`.claude/agents/reviewer.md`'s rule 3. This was deliberately deferred to keep the initial
roster small (6 subagents, see `.claude/agents/`) — it's the first place to grow, not the
last.

## 5. Package manager: npm/yarn instead of pnpm

Already works without changing a single file — this was tested by actually installing with
all three package managers on a clean clone, not assumed. `scripts/verify.sh` and
`.claude/hooks/format.sh` call binaries via `node_modules/.bin/<tool>` directly, never
`pnpm exec`, so they don't care who populated `node_modules`:

```bash
npm install     # or: yarn install
```

One thing to know: Yarn Berry defaults to PnP mode, which creates no `node_modules/` at all —
`.yarnrc.yml` in this repo pins `nodeLinker: node-modules` specifically so `yarn install`
still produces the layout every tool here expects. Don't remove that file if you keep Yarn as
an option.

If you fully commit to npm or yarn and never go back to pnpm, you can remove
`pnpm-lock.yaml`, `pnpm-workspace.yaml`, and the `packageManager` field in `package.json` —
none of it is required for the other two to work, it's just what CI and this repo default to.
`pnpm verify` becomes `npm run verify` / `yarn verify` regardless of which lockfiles you keep —
the script name doesn't change, only how you invoke it.

## 6. Adapt the gates

- **Add a pyramid step:** edit `scripts/verify.sh`'s `STEP_NAMES`/`STEP_CMDS` arrays and
  `count_failures_for_step`, keeping the `--json` output shape (`exit_code`, `failure_count`,
  `steps[]`) intact — `verify-gate.sh`'s ratchet depends on that shape.
- **Add/change a hook:** edit the referenced `.claude/hooks/*.sh` script for behavior changes,
  or `.claude/hooks/definitions.json` for event wiring changes, then run `pnpm gen-hooks` to
  regenerate the Copilot `.github/hooks/*.json` mirrors.
- **Change ratchet thresholds:** `MAX_ATTEMPTS` in `.claude/hooks/verify-gate.sh` (default 6,
  must stay below the Claude Code native Stop-hook block cap, which was 8 as of this
  template's generation — check Claude Code's current docs, or raise
  `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` to be safe regardless of the exact number).

## 7. Token budgets

Per-role budgets are guidance, not enforced code — a default trocável tuned for small tasks
(see the table in `docs/meta/AGENT_ARCHITECTURE.md` §3.5 if still present, or just each
subagent's own file under `.claude/agents/` for its role). If your project's tasks are larger,
raise them; there's no single file to edit, just the judgment you apply when a subagent's
output looks like it's running long.
