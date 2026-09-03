#!/usr/bin/env bash
# PostToolUse(*) — append one observability line per tool call. Never
# blocks. SPEC.md §5, hook #7 / docs/meta/AGENT_ARCHITECTURE.md §3.5.
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_DIR="$REPO_ROOT/.claude/logs"
mkdir -p "$LOG_DIR"

input="$(cat)"

node -e "
let d='';
process.stdin.on('data', c => d += c);
process.stdin.on('end', () => {
  let payload;
  try { payload = JSON.parse(d); } catch { payload = {}; }
  const line = {
    ts: new Date().toISOString(),
    role: payload.subagent_type ?? payload.agent_name ?? 'main',
    model: payload.model ?? null,
    tool: payload.tool_name ?? null,
    tokens_in: payload.usage?.input_tokens ?? null,
    tokens_out: payload.usage?.output_tokens ?? null,
    cache_read_tokens: payload.usage?.cache_read_input_tokens ?? null,
  };
  require('fs').appendFileSync(process.argv[1], JSON.stringify(line) + '\n');
});
" "$LOG_DIR/metrics.jsonl" <<<"$input"

exit 0
