#!/usr/bin/env bash
# PreToolUse(Write|Edit) — deny dangerouslySetInnerHTML without a sanitizer
# call in the same new content. SPEC.md §5, hook #3.
set -uo pipefail

input="$(cat)"
content="$(node -e "
  let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    try {
      const t = JSON.parse(d).tool_input ?? {};
      console.log(t.content ?? t.new_string ?? '');
    } catch { console.log(''); }
  });" <<<"$input")"

if echo "$content" | grep -q 'dangerouslySetInnerHTML'; then
  if ! echo "$content" | grep -Eq '(DOMPurify\.sanitize|sanitizeHtml)\(' ; then
    node -e "console.log(JSON.stringify({hookSpecificOutput:{hookEventName:'PreToolUse',permissionDecision:'deny',permissionDecisionReason:'dangerouslySetInnerHTML found without a sanitizer call (DOMPurify.sanitize(...) or sanitizeHtml(...)) in the same edit. Wrap the HTML string in a sanitizer before assigning it.'}}))"
    exit 0
  fi
fi

exit 0
