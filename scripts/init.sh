#!/usr/bin/env bash
# scripts/init.sh — one-time interactive setup for a project cloned from
# frontend-agent-template. Automates docs/CUSTOMIZING.md §1: rebrands the
# project, drops the meta/process docs (how THIS template was generated —
# not your project's history), and re-initializes git history.
#
# Safe to re-run only up to the point it re-inits git — after that it
# refuses (a second run would wipe your own commits). Run this once,
# right after cloning, before you write any real code.
#
# Usage:
#   scripts/init.sh                         interactive prompts
#   scripts/init.sh --name "my-app" \
#     --description "One-line mission" --yes    non-interactive (CI/scripting)
set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NAME=""
DESCRIPTION=""
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2 ;;
    --description) DESCRIPTION="${2:-}"; shift 2 ;;
    --yes|-y) ASSUME_YES=true; shift ;;
    *) echo "unknown flag: $1" >&2; exit 64 ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$1"; }

# A fresh clone of the template always has git history (the template's own
# commits) — that's expected and NOT a sign init.sh already ran, so commit
# history is the wrong signal to check. docs/meta/ is: it only exists in an
# un-initialized clone, since this script's own job is to delete it.
if [[ ! -d docs/meta ]]; then
  bold "docs/meta/ is already gone — looks like init.sh already ran here (or this"
  echo "isn't a fresh clone of the template). Refusing to run again — a second run"
  echo "would wipe your git history. Remove .git yourself first if you really want to."
  exit 1
fi

bold "== frontend-agent-template setup =="
echo "This rebrands the project, removes docs/meta/ (the paper trail of how this"
echo "template itself was generated — not needed for your project), and starts a"
echo "fresh git history. It does not touch specs/example-feature/ or the example"
echo "app code — read docs/CUSTOMIZING.md when you're ready to remove those."
echo

if [[ -z "$NAME" ]]; then
  read -r -p "Project name (kebab-case, e.g. my-app): " NAME
fi
NAME="${NAME:-my-app}"

if [[ -z "$DESCRIPTION" ]]; then
  read -r -p "One-line mission for CLAUDE.md (what does this project do): " DESCRIPTION
fi
DESCRIPTION="${DESCRIPTION:-A frontend project built with a Spec-Driven Development harness.}"

if ! $ASSUME_YES; then
  echo
  echo "About to:"
  echo "  1. Remove docs/meta/"
  echo "  2. Rename the project to \"$NAME\" in package.json, README.md, CLAUDE.md"
  echo "  3. Set CLAUDE.md's mission line to: \"$DESCRIPTION\""
  echo "  4. Remove .git and start a fresh history with one initial commit"
  read -r -p "Continue? [y/N] " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted, nothing changed."
    exit 0
  fi
fi

echo
echo "-> Removing docs/meta/"
rm -rf docs/meta

echo "-> Renaming project to \"$NAME\""
node -e "
  const fs = require('node:fs');
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  pkg.name = process.argv[1];
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
" "$NAME"

node -e "
  const fs = require('node:fs');
  const name = process.argv[1];
  const description = process.argv[2];

  let claude = fs.readFileSync('CLAUDE.md', 'utf8');
  claude = claude.replace(/^# frontend-agent-template\n/m, '# ' + name + '\n');
  claude = claude.replace(
    /^A Spec-Driven Development harness[\s\S]*?your actual project\.\n/m,
    description + '\n',
  );
  fs.writeFileSync('CLAUDE.md', claude);

  let readme = fs.readFileSync('README.md', 'utf8');
  readme = readme.replace(/^# frontend-agent-template\n/m, '# ' + name + '\n');
  fs.writeFileSync('README.md', readme);
" "$NAME" "$DESCRIPTION"

echo "-> Re-initializing git history"
rm -rf .git
git init -q
git branch -m main
git add -A
git commit -q -m "Initial commit from frontend-agent-template

Generated with scripts/init.sh. See docs/CUSTOMIZING.md for the rest of
the setup (swapping stack layers, removing the example feature once
you've read it, adding your first real /spec)."

echo
bold "Done. Next steps:"
echo "  1. pnpm install    (or npm/yarn — see docs/CUSTOMIZING.md §5)"
echo "  2. pnpm verify     (confirm the pyramid is green before you touch anything)"
echo "  3. Open Claude Code here and run /spec to describe your first real feature."
echo "  4. When you understand the pattern, remove specs/example-feature/ and the"
echo "     SubscribeDialog/queries/handlers example code (docs/CUSTOMIZING.md §1)."
