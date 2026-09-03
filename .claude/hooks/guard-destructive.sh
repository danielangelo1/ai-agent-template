#!/usr/bin/env bash
# PreToolUse(Bash) — deny destructive commands before they run.
# SPEC.md §5, hook #1.
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
input="$(cat)"
command="$(node -e "
  let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    try { console.log(JSON.parse(d).tool_input?.command ?? ''); } catch { console.log(''); }
  });" <<<"$input")"

deny() {
  node -e "console.log(JSON.stringify({hookSpecificOutput:{hookEventName:'PreToolUse',permissionDecision:'deny',permissionDecisionReason:process.argv[1]}}))" "$1"
  exit 0
}

# rm -rf: allow inside the repo (below its root) or in a recognized OS/agent
# scratch dir (/tmp, /private/tmp, /var/folders/**, anything with
# "scratchpad" in the path); deny everything else — including the repo
# root itself (that would wipe the whole project) and any path outside it.
#
# The command is split into segments on shell separators (; && || | and
# newlines) FIRST, and only a segment whose own first word is "rm" is
# inspected — this avoids false positives where a later, unrelated command
# in the same multi-line call happens to mention a path that looks like the
# repo root (e.g. `git clone <repo-root> /tmp/x` right after an unrelated
# `rm -rf` on a different line).
rm_verdict="$(node -e "
  const path = require('node:path');
  const repoRoot = path.resolve(process.argv[1]);
  const command = process.argv[2];

  const isScratch = (p) => /^\/(private\/)?tmp\//.test(p) || /^\/var\/folders\//.test(p) || /scratchpad/.test(p);
  const isRmRf = (flags) => /r/.test(flags) && /f/.test(flags);

  const segments = command.split(/(?:;|&&|\|\||\||\n)+/).map((s) => s.trim()).filter(Boolean);

  for (const segment of segments) {
    const words = segment.split(/\s+/);
    if (words[0] !== 'rm') continue;

    const flagWords = words.slice(1).filter((w) => w.startsWith('-'));
    const hasRf = flagWords.some((w) => isRmRf(w.replace(/^-+/, '')));
    if (!hasRf) continue;

    const targets = words.slice(1).filter((w) => w && !w.startsWith('-'));
    if (targets.length === 0) { console.log('deny:no target path found in \'' + segment + '\''); process.exit(0); }

    for (const t of targets) {
      const resolved = path.resolve(repoRoot, t);
      if (isScratch(resolved)) continue;
      if (resolved === repoRoot) { console.log('deny:target is the repository root itself'); process.exit(0); }
      if (!resolved.startsWith(repoRoot + path.sep)) { console.log('deny:target (' + resolved + ') resolves outside the repository root'); process.exit(0); }
    }
  }
  console.log('allow');
" "$REPO_ROOT" "$command")"

if [[ "$rm_verdict" != "allow" ]]; then
  deny "rm -rf blocked: ${rm_verdict#deny:}. Allowed: paths inside the repo (below its root) or a recognized scratch dir (/tmp, /private/tmp, /var/folders/**, *scratchpad*)."
fi

# force-push
if echo "$command" | grep -Eq 'git[[:space:]]+push[[:space:]].*(-f\b|--force\b)'; then
  deny "force-push is blocked in-session. Ask the human to run it manually if truly needed."
fi

# hard reset
if echo "$command" | grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard'; then
  deny "git reset --hard is blocked. Use the ratchet's surgical revert (verify-gate.sh) or ask a human."
fi

# reading secrets directly
if echo "$command" | grep -Eq '(^|[;&|]\s*)(cat|less|more)[[:space:]]+.*\.env(\.|[[:space:]]|$)'; then
  deny "reading .env files directly is blocked. Use .env.example for placeholders."
fi
if echo "$command" | grep -Eq '(^|[;&|]\s*)(printenv|env)([[:space:]]|$)'; then
  deny "dumping the full environment is blocked (secrets may be present). Reference a specific known-safe variable instead."
fi

exit 0
