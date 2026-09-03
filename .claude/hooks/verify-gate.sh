#!/usr/bin/env bash
# Stop / SubagentStop — the green gate. Implements the ratchet exactly as
# specified in SPEC.md §5. This is the ONLY hook allowed to block the end
# of a turn on verification grounds.
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="$REPO_ROOT/.claude/state"
STATE_FILE="$STATE_DIR/verify-ratchet.json"
ACTIVE_FEATURE_FILE="$STATE_DIR/active-feature"
MAX_ATTEMPTS=6

mkdir -p "$STATE_DIR"

input="$(cat)"
stop_hook_active="$(node -e "
  let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    try { console.log(JSON.parse(d).stop_hook_active === true ? 'true' : 'false'); }
    catch { console.log('false'); }
  });" <<<"$input")"

# Rule 1 (SPEC.md §5): never recount a block the harness is already processing.
if [[ "$stop_hook_active" == "true" ]]; then
  exit 0
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"last_good_sha":"","last_failure_count":999999,"attempts_this_task":0}' >"$STATE_FILE"
fi

last_good_sha="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).last_good_sha)" "$STATE_FILE")"
last_failure_count="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).last_failure_count)" "$STATE_FILE")"
attempts="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).attempts_this_task)" "$STATE_FILE")"

result_json="$(bash "$REPO_ROOT/scripts/verify.sh" --json)"
exit_code="$(node -e "console.log(JSON.parse(process.argv[1]).exit_code)" "$result_json")"
failure_count="$(node -e "console.log(JSON.parse(process.argv[1]).failure_count)" "$result_json")"

block() {
  local message="$1"
  node -e "console.log(JSON.stringify({decision:'block',reason:process.argv[1]}))" "$message"
  exit 2
}

write_state() {
  node -e "
    require('fs').writeFileSync(process.argv[1], JSON.stringify({
      last_good_sha: process.argv[2],
      last_failure_count: Number(process.argv[3]),
      attempts_this_task: Number(process.argv[4]),
    }, null, 2));
  " "$STATE_FILE" "$1" "$2" "$3"
}

# Case 1: verify passed — record checkpoint, reset ratchet, let the turn end.
if [[ "$exit_code" == "0" ]]; then
  new_sha=""
  if git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
    new_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  fi
  write_state "$new_sha" 0 0
  exit 0
fi

attempts=$((attempts + 1))

# Case 3: attempt cap reached — hand off to a human gracefully, BEFORE the
# native Claude Code Stop-hook block cap of 8 (research/FINDINGS.md §2.1.4).
if [[ $attempts -ge $MAX_ATTEMPTS ]]; then
  feature="$(cat "$ACTIVE_FEATURE_FILE" 2>/dev/null || echo "")"
  if [[ -n "$feature" && -d "$REPO_ROOT/specs/$feature" ]]; then
    handoff_path="$REPO_ROOT/specs/$feature/HANDOFF_NEEDED.md"
  else
    handoff_path="$STATE_DIR/HANDOFF_NEEDED.md"
  fi
  {
    echo "# Handoff needed"
    echo
    echo "verify-gate.sh reached $MAX_ATTEMPTS attempts without reaching GREEN."
    echo
    echo "- Last failure count: $failure_count"
    echo "- Last known-good commit: ${last_good_sha:-none}"
    echo
    echo "\`\`\`json"
    echo "$result_json"
    echo "\`\`\`"
  } >"$handoff_path"
  write_state "$last_good_sha" "$failure_count" 0
  echo "Handoff written to $handoff_path after $MAX_ATTEMPTS attempts." >&2
  exit 0
fi

# Case 2: progress — failure count strictly decreased. Block, don't revert.
if [[ "$failure_count" -lt "$last_failure_count" ]]; then
  write_state "$last_good_sha" "$failure_count" "$attempts"
  block "Progress made ($last_failure_count -> $failure_count failures) but not GREEN yet. Remaining: $result_json"
fi

# Case 4: regression or stagnation — surgically revert files touched this
# turn to last_good_sha, then block.
if [[ -n "$last_good_sha" ]]; then
  changed_files="$(git -C "$REPO_ROOT" diff --name-only "$last_good_sha" -- 2>/dev/null || true)"
  if [[ -n "$changed_files" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      git -C "$REPO_ROOT" checkout "$last_good_sha" -- "$f" 2>/dev/null || true
    done <<<"$changed_files"
  fi
fi

write_state "$last_good_sha" "$failure_count" "$attempts"
block "The last change made things worse or did not improve ($last_failure_count -> $failure_count failures). Files touched this turn were reverted to the last known-good state. Try a different approach. Remaining: $result_json"
