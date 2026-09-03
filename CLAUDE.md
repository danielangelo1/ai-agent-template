# frontend-agent-template

A Spec-Driven Development harness for frontend work, built for Claude Code (native) and
GitHub Copilot (thin adapter — see `ADR-001` in `docs/DECISIONS.md`). Clone this and swap the
mission line above and the stack in `SPEC.md` §2 for your actual project.

## Pipeline commands

| Command      | Does                                                                     |
| ------------ | ------------------------------------------------------------------------ |
| `/spec`      | Turn a request into `specs/<feature>/spec.md` (EARS acceptance criteria) |
| `/plan`      | Spawn `planner` → `plan.md` + `tasks.md`                                 |
| `/tasks`     | Light manual edit of an existing `tasks.md`                              |
| `/implement` | RED→GREEN loop over all tasks, gated by the ratchet                      |
| `/tdd`       | One RED→GREEN cycle for a single task                                    |
| `/review`    | Independent `reviewer` + `a11y-auditor`, parallel                        |
| `/ship`      | Full `scripts/verify.sh`, open the PR                                    |

Each command is a skill under `.claude/skills/` — read the skill, don't ask what it does.
Expertise skills (component conventions, routing, state, styling, testing, a11y, error
handling, OpenAPI codegen) load automatically when relevant; you don't need to read them
manually either.

## The 3 non-negotiables

1. **Nothing is "done" without `scripts/verify.sh` exiting 0.** The `Stop`/`SubagentStop` hook
   (`verify-gate.sh`) enforces this — you cannot declare a task finished by saying so.
2. **TDD is mandatory.** `test-author` writes a failing test before `implementer` writes any
   code. No exceptions for "obviously correct" changes.
3. **`reviewer` is never the same session that implemented.** It is spawned fresh, never via
   `context: fork` — see `docs/AGENT_ARCHITECTURE.md` §3.1.

## Where things live

- `SPEC.md` — the full contract (stack, subagents, hooks, verification pyramid, roadmap).
- `docs/AGENT_ARCHITECTURE.md` — why the roster/gates look like this.
- `docs/DECISIONS.md` — ADRs for every opinionated default.
- `docs/CUSTOMIZING.md` — how to swap a stack layer, add a skill/subagent, adapt a gate.
- `specs/_TEMPLATE/` — EARS spec/plan/tasks templates for a new feature.

## Cloned this template? Start here

`docs/CUSTOMIZING.md` has the full guide. Do not read `research/` or `docs/DECISIONS.md` as
project context for your own feature work — those are artifacts of generating this template,
not your project's history.
