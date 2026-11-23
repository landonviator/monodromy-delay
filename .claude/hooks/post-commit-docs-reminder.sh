#!/bin/sh
# PostToolUse hook, filtered to `git commit` (see settings.json `if`).
# Reminds Claude to keep docs in sync with what the commit changed.
# Stdout JSON is injected into Claude's context via additionalContext.

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Docs-sync reminder (CLAUDE.md rule): move any finished ROADMAP.md items to CHANGELOG.md (newest first) and add new follow-ups; update docs/decisions.md only for a notable choice the code cannot show."}}
JSON
