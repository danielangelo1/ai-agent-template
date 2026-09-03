#!/usr/bin/env bash
# scripts/verify.sh — the verification pyramid (SPEC.md §6).
# Single source of truth called by: humans, .claude/hooks/verify-gate.sh, and CI.
#
# Usage:
#   scripts/verify.sh                 full pyramid, stop at first failure (human mode)
#   scripts/verify.sh --json          full pyramid, run ALL steps, JSON summary on stdout
#   scripts/verify.sh --unit          only step 3 (unit/component tests)
#   scripts/verify.sh --unit --file <path>   only step 3, scoped to one test file
#   scripts/verify.sh --a11y          only step 6 (route-level a11y scan)
set -uo pipefail

JSON_MODE=false
UNIT_ONLY=false
A11Y_ONLY=false
UNIT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=true; shift ;;
    --unit) UNIT_ONLY=true; shift ;;
    --a11y) A11Y_ONLY=true; shift ;;
    --file) UNIT_FILE="${2:-}"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 64 ;;
  esac
done

# steps[] entries: "name|command|failure-count-strategy"
# failure-count-strategy: "boolean" (0 or 1) | "count:<regex-with-one-capture-group>"
STEP_NAMES=(format typecheck lint unit e2e build a11y)
STEP_CMDS=(
  "pnpm exec prettier --check ."
  "pnpm exec tsc -b"
  "pnpm exec eslint ."
  "pnpm exec vitest run"
  "pnpm exec playwright test --grep @critical"
  "pnpm exec vite build"
  "pnpm exec playwright test --grep @a11y"
)

run_step() {
  local idx="$1"
  local name="${STEP_NAMES[$idx]}"
  local cmd="${STEP_CMDS[$idx]}"
  local out
  out="$(eval "$cmd" 2>&1)"
  local code=$?
  echo "$out"
  return $code
}

count_failures_for_step() {
  # Best-effort structured failure count per step, used only by --json for
  # the ratchet's failure_count comparison (SPEC.md §5 verify-gate.sh).
  local name="$1" output="$2" code="$3"
  case "$name" in
    format)
      grep '^\[warn\]' <<<"$output" | grep -vc 'Code style issues found' || true ;;
    typecheck)
      grep -Ec ': error TS[0-9]+:' <<<"$output" || true ;;
    lint)
      grep -Eo '[0-9]+ error' <<<"$output" | head -1 | grep -Eo '^[0-9]+' || echo 0 ;;
    unit|e2e|a11y)
      grep -Eo '[0-9]+ failed' <<<"$output" | head -1 | grep -Eo '^[0-9]+' || {
        [[ $code -ne 0 ]] && echo 1 || echo 0
      } ;;
    build)
      [[ $code -ne 0 ]] && echo 1 || echo 0 ;;
    *) echo 0 ;;
  esac
}

steps_to_run=()
if $UNIT_ONLY; then
  steps_to_run=(3)
  if [[ -n "$UNIT_FILE" ]]; then
    STEP_CMDS[3]="pnpm exec vitest run \"$UNIT_FILE\""
  fi
elif $A11Y_ONLY; then
  steps_to_run=(6)
else
  steps_to_run=(0 1 2 3 4 5 6)
fi

total_failures=0
overall_code=0
json_steps="[]"

for idx in "${steps_to_run[@]}"; do
  name="${STEP_NAMES[$idx]}"
  output="$(run_step "$idx")"
  code=$?
  failures="$(count_failures_for_step "$name" "$output" "$code")"
  failures="${failures:-0}"
  passed="true"
  if [[ $code -ne 0 ]]; then
    passed="false"
    overall_code=1
    total_failures=$((total_failures + failures))
  fi

  if $JSON_MODE; then
    step_json="{\"name\":\"$name\",\"passed\":$passed,\"count\":$failures}"
    json_steps="$(node -e "
      const steps = $json_steps;
      steps.push($step_json);
      console.log(JSON.stringify(steps));
    ")"
  else
    if [[ $code -eq 0 ]]; then
      echo "✓ $name"
    else
      echo "✗ $name"
      echo "$output"
      exit "$code"
    fi
  fi
done

if $JSON_MODE; then
  echo "{\"exit_code\":$([[ $overall_code -eq 0 ]] && echo 0 || echo 1),\"failure_count\":$total_failures,\"steps\":$json_steps}"
else
  echo "All requested checks passed."
fi

exit $overall_code
