# frontend-agent-template

A clonable Spec-Driven Development harness that turns Claude Code (and, via a thin adapter,
GitHub Copilot) into a frontend engineering agent: mandatory TDD, an independent reviewer, a
deterministic verification gate that the agent cannot talk its way past, and a small example
app that proves the whole loop actually works.

Read `SPEC.md` first — it's the full contract this repo implements. `CLAUDE.md` is what the
agent itself reads every session; `docs/CUSTOMIZING.md` is what you read when you clone this
for a real project.

## Quick start

```bash
pnpm install            # or npm/yarn — see docs/CUSTOMIZING.md §5
pnpm verify              # the full verification pyramid (SPEC.md §6)
pnpm dev                 # example app at http://localhost:5173
```

## What's here

| Path                         | What                                                                          |
| ---------------------------- | ----------------------------------------------------------------------------- |
| `SPEC.md`                    | The contract: stack, subagents, hooks, verification pyramid, roadmap          |
| `docs/AGENT_ARCHITECTURE.md` | Why the roster/gates look like this                                           |
| `docs/DECISIONS.md`          | ADRs for every opinionated default                                            |
| `docs/CUSTOMIZING.md`        | How to clone this and adapt it                                                |
| `research/FINDINGS.md`       | The sourced research this template was built from                             |
| `.claude/`                   | Subagents, skills (= commands + expertise), hooks — the Claude Code harness   |
| `.github/`                   | The Copilot adapter (prompts, hooks, workflows) generated from `.claude/`     |
| `src/`, `tests/`             | The example app (a newsletter-signup feature) proving the harness works       |
| `specs/example-feature/`     | That feature's spec/plan/tasks, as `/spec`→`/plan`→`/implement` would produce |
| `scripts/verify.sh`          | The verification pyramid — same script for humans, hooks, and CI              |

## Non-negotiables

1. Nothing is "done" without `scripts/verify.sh` exiting 0.
2. TDD is mandatory — a failing test before any implementation code.
3. The reviewer is never the same session that implemented.

See `CLAUDE.md` for the full pipeline command list (`/spec`, `/plan`, `/implement`, `/review`,
`/ship`, ...).
