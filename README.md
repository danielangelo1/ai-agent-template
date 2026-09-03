# frontend-agent-template

A clonable Spec-Driven Development harness that turns Claude Code (and, via a thin adapter,
GitHub Copilot) into a frontend engineering agent: mandatory TDD, an independent reviewer, a
deterministic verification gate that the agent cannot talk its way past, and a small example
app that proves the whole loop actually works end to end.

## Quickstart: use this for a new project

```bash
git clone <this-repo> my-project && cd my-project
scripts/init.sh          # interactive: renames the project, drops the meta docs,
                          # starts a fresh git history — see docs/CUSTOMIZING.md §1
pnpm install              # or npm/yarn — both work with zero changes, see §5
pnpm verify                # confirm the pyramid is green before you touch anything
```

Then open Claude Code (or Copilot) in that directory and describe your first feature —
`/spec a user can reset their password by email`. The agent takes it from there, stopping for
your approval at the checkpoints described below. See ["How to use the agent"](#how-to-use-the-agent)
for a full walkthrough.

## How to use the agent

The pipeline is 5 slash-commands, chained, with a human checkpoint after each of the first two
and a hard gate before the last one. You never write application code by hand in this flow —
you write the spec, approve the plan, and review what comes out.

```
/spec <description>          you describe a feature in plain language
   │
   ▼  writes specs/<feature>/spec.md (EARS acceptance criteria)
   │  ← YOU APPROVE (or ask for changes) before continuing
   ▼
/plan                        spawns the `planner` subagent
   │
   ▼  writes specs/<feature>/plan.md + tasks.md
   │  ← YOU APPROVE the task breakdown before continuing
   ▼
/implement                   runs unattended, task by task:
   │    test-author writes a failing test (RED)
   │    implementer makes it pass (GREEN)
   │    verify-gate.sh blocks each step until scripts/verify.sh is 0
   │    stuck 6x on one task? it stops and writes HANDOFF_NEEDED.md — never loops forever
   ▼
/review                      spawns `reviewer` (fresh session, never the implementer)
   │                          + `a11y-auditor`, in parallel
   ▼  high-severity findings block /ship until fixed or explicitly waived
   ▼
/ship                        full pyramid one more time, opens the PR
   │  ← YOU APPROVE the merge — this step never merges on its own
```

A few things worth knowing before your first run:

- **You can stop mid-flow at any point.** `/tasks` lets you hand-edit a task list without
  re-running `/plan`; `/tdd` runs one task's RED→GREEN cycle in isolation if you'd rather work
  task by task than let `/implement` batch through all of them.
- **Nothing is ever "done" because the agent says so.** `scripts/verify.sh` (format → typecheck
  → lint → unit → e2e → build → a11y) is the only thing that decides pass/fail, for the agent
  and for CI — run `pnpm verify` yourself any time to check the same thing it checks.
  See [`scripts/verify.sh`](scripts/verify.sh).
- **If `/implement` gets stuck**, look for a `specs/<feature>/HANDOFF_NEEDED.md` file — that's
  the agent asking for help instead of guessing or looping. It's not an error to be afraid of,
  it's the harness working as designed.
- **Full command list and the 3 non-negotiable rules** live in [`CLAUDE.md`](CLAUDE.md) — that's
  the file the agent itself reads every session, so it's always the source of truth for "what
  can I ask it to do."

## What's here

| Path                     | What                                                                                                                                                                                                                         |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/init.sh`        | Run this first — rebrands the project, starts fresh git history                                                                                                                                                              |
| `CLAUDE.md`              | What the agent reads every session — commands, non-negotiables, pointers                                                                                                                                                     |
| `docs/CUSTOMIZING.md`    | How to clone this, swap a stack layer, add a skill/subagent, adapt a gate                                                                                                                                                    |
| `SPEC.md`                | The full contract: stack, subagents, hooks, verification pyramid                                                                                                                                                             |
| `.claude/`               | Subagents, skills (= commands + expertise), hooks — the Claude Code harness                                                                                                                                                  |
| `.github/`               | The Copilot adapter (prompts, hooks, workflows), generated from `.claude/`                                                                                                                                                   |
| `scripts/verify.sh`      | The verification pyramid — same script for humans, hooks, and CI                                                                                                                                                             |
| `src/`, `tests/`         | The example app (a newsletter-signup feature) proving the harness works                                                                                                                                                      |
| `specs/example-feature/` | That feature's spec/plan/tasks, as `/spec`→`/plan`→`/implement` would produce                                                                                                                                                |
| `specs/_TEMPLATE/`       | Empty EARS spec/plan/tasks templates for your first real feature                                                                                                                                                             |
| `docs/meta/`             | Why this template looks the way it does — architecture rationale, ADRs, the sourced research it was built from. **Not needed to use the template** — `scripts/init.sh` removes it. Kept in this origin repo for maintainers. |

## Non-negotiables

1. Nothing is "done" without `scripts/verify.sh` exiting 0.
2. TDD is mandatory — a failing test before any implementation code.
3. The reviewer is never the same session that implemented.
