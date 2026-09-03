# TOKEN_BUDGET.md

Observability for the harness itself — cost per task, cache hit rate, tool-call count. See
`docs/AGENT_ARCHITECTURE.md` §3.5 for the per-role budget table and the design rationale.

## Where the data comes from

`.claude/hooks/log-metrics.sh` runs on every `PostToolUse` event and appends one JSON line to
`.claude/logs/metrics.jsonl` (gitignored — this is per-clone, per-machine data, never
committed):

```json
{"ts":"...","role":"implementer","model":"claude-sonnet-5","tool":"Edit","tokens_in":...,"tokens_out":...,"cache_read_tokens":...}
```

Some fields (`tokens_in`, `tokens_out`, `cache_read_tokens`) are only populated when the
Claude Code hook payload includes usage data for that event — treat `null` as "not reported
for this call," not "zero."

## Aggregating it

No dashboard is bundled (deliberately — this is a template, not an observability platform).
A few `jq` one-liners cover the common questions:

```bash
# Tool calls per role, most recent session
jq -s 'group_by(.role) | map({role: .[0].role, calls: length})' .claude/logs/metrics.jsonl

# Total input/output tokens today
jq -s '[.[] | select(.ts | startswith("'"$(date -u +%F)"'"))] |
  {tokens_in: (map(.tokens_in // 0) | add), tokens_out: (map(.tokens_out // 0) | add)}' \
  .claude/logs/metrics.jsonl

# Rough cache hit rate (cache_read_tokens / tokens_in) for subagent-heavy roles
jq -s '[.[] | select(.role != "main" and .tokens_in != null)] |
  {cache_read: (map(.cache_read_tokens // 0) | add), total_in: (map(.tokens_in) | add)}' \
  .claude/logs/metrics.jsonl
```

## What to watch for

- **Cache hit rate near 0% for repeated subagent roles** (`test-author`/`implementer` called
  task after task in the same `/implement` run): subagents default to a 5-minute cache TTL
  even on a subscription plan (`research/FINDINGS.md` §2.1.9). If tasks are spaced further
  apart than 5 minutes, each pays full cache-write cost. Fix: set
  `experimental.cacheTtl: "1h"` in the relevant subagent's frontmatter if your Claude Code
  version supports it (v2.1.248+ — check with `claude --version` before relying on this).
- **A role consistently near its budget cap** (`docs/AGENT_ARCHITECTURE.md` §3.5 table): either
  the role's tasks are genuinely larger than the template's default assumption (raise the
  budget — it's a convention, not enforced code, see `CUSTOMIZING.md` §7), or the task
  decomposition from `planner` is too coarse (fix the plan, not the budget).
- **`attempts_this_task` repeatedly hitting the ratchet's cap** (`.claude/state/verify-ratchet.json`,
  or `HANDOFF_NEEDED.md` files appearing under `specs/*/`): a signal the task was under-specified
  by `planner`, not that `implementer` needs a bigger budget.
