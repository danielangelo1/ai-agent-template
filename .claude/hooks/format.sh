#!/usr/bin/env bash
# PostToolUse(Write|Edit) — format the edited file. Never blocks.
# SPEC.md §5, hook #5.
set -uo pipefail

input="$(cat)"
target="$(node -e "
  let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    try {
      const t = JSON.parse(d).tool_input ?? {};
      console.log(t.file_path ?? t.path ?? '');
    } catch { console.log(''); }
  });" <<<"$input")"

[[ -z "$target" || ! -f "$target" ]] && exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BIN="$REPO_ROOT/node_modules/.bin"

"$BIN/prettier" --write "$target" >/dev/null 2>&1 || true

case "$target" in
  *.ts|*.tsx|*.js|*.jsx)
    "$BIN/eslint" --fix "$target" >/dev/null 2>&1 || true
    ;;
esac

exit 0
