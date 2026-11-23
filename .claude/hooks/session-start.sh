#!/bin/sh
# SessionStart hook: surface the open roadmap items.
# Stdout is injected into Claude's context at session start.
DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [ -f "$DIR/ROADMAP.md" ]; then
  echo "===== Open roadmap items (unchecked) ====="
  if grep -q '^- \[ \]' "$DIR/ROADMAP.md"; then
    grep '^- \[ \]' "$DIR/ROADMAP.md"
  else
    echo "(none open)"
  fi
fi
