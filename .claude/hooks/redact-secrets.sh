#!/usr/bin/env bash
# PostToolUse(Bash) — redact likely secrets from command output before it
# re-enters the model's context. Never blocks. SPEC.md §5, hook #4.
set -uo pipefail

input="$(cat)"

node -e "
let d='';
process.stdin.on('data', c => d += c);
process.stdin.on('end', () => {
  let payload;
  try { payload = JSON.parse(d); } catch { console.log(JSON.stringify({})); return; }

  const patterns = [
    /sk-[a-zA-Z0-9]{20,}/g,
    /ghp_[a-zA-Z0-9]{36}/g,
    /gh[oprsu]_[a-zA-Z0-9]{36,}/g,
    /AKIA[A-Z0-9]{16}/g,
    /eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/g, // JWT-shaped
  ];

  const raw = payload.tool_response ?? payload.output ?? '';
  const text = typeof raw === 'string' ? raw : JSON.stringify(raw);
  let redacted = text;
  let found = false;
  for (const p of patterns) {
    if (p.test(redacted)) { found = true; }
    redacted = redacted.replace(p, '[REDACTED]');
  }

  if (found) {
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: 'Note: this command output contained what looks like a secret/token; it was redacted before reaching the model context.',
      },
      systemMessage: redacted,
    }));
  } else {
    console.log(JSON.stringify({}));
  }
});
" <<<"$input"

exit 0
