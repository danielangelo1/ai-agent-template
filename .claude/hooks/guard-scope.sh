#!/usr/bin/env bash
# PreToolUse(Write|Edit) — deny writes that resolve outside the repo root.
# SPEC.md §5, hook #2.
set -uo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
input="$(cat)"
target="$(node -e "
  let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    try {
      const t = JSON.parse(d).tool_input ?? {};
      console.log(t.file_path ?? t.path ?? '');
    } catch { console.log(''); }
  });" <<<"$input")"

if [[ -z "$target" ]]; then
  exit 0
fi

verdict="$(node -e "
  const path = require('node:path');
  const repoRoot = path.resolve(process.argv[1]);
  const resolved = path.resolve(process.argv[2]);

  const isScratch = (p) => /^\/(private\/)?tmp\//.test(p) || /^\/var\/folders\//.test(p) || /scratchpad/.test(p);

  // Boundary-safe check: a naive string-prefix check would wrongly allow a
  // sibling dir like '<repoRoot>-evil' just because it shares the prefix.
  const inRepo = resolved === repoRoot || resolved.startsWith(repoRoot + path.sep);

  console.log(inRepo || isScratch(resolved) ? 'allow' : 'deny:' + resolved);
" "$repo_root" "$target")"

if [[ "$verdict" != "allow" ]]; then
  node -e "console.log(JSON.stringify({hookSpecificOutput:{hookEventName:'PreToolUse',permissionDecision:'deny',permissionDecisionReason:'Write target resolves outside the repository root ('+process.argv[1]+'). Allowed: paths inside the repo, or a recognized scratch dir (/tmp, /private/tmp, /var/folders/**, *scratchpad*).'}}))" "${verdict#deny:}"
  exit 0
fi

exit 0
