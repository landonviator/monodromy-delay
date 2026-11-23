#!/bin/sh
# PreToolUse guard: the hard safety net for autonomous mode.
#
# Reads the tool-call JSON on stdin, inspects the real command / file path, and
# blocks irreversible actions. Exit 2 => the call is blocked and
# the stderr message is fed back to Claude as the reason. Exit 0 => allowed.
#
# This is the actual enforcement; the permissions.deny globs in settings.json are
# only a cheap backstop (they can be glob-dodged; this cannot).

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

deny() {
  printf 'BLOCKED by pre-tool-guard: %s\n' "$1" >&2
  exit 2
}

# ---- protected sub-trees inside the repo (submodules + build output) ----
path_protected() {
  case "$1" in
    "$REPO"/libs/JUCE | "$REPO"/libs/JUCE/*) return 0 ;;
    "$REPO"/build | "$REPO"/build/* | */build/*) return 0 ;;
    */cmake-build-*/*) return 0 ;;
    *) return 1 ;;
  esac
}

case "$tool" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    [ -z "$cmd" ] && exit 0

    # --- destructive filesystem ---
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])rm[[:space:]]+(-[^[:space:]]*[rR]|--recursive)' \
      && deny "recursive rm (rm -r/-rf) is not allowed"
    printf '%s' "$cmd" | grep -Eq '\.Trash' \
      && deny "touching the macOS Trash is not allowed"
    printf '%s' "$cmd" | grep -Eiq 'osascript' \
      && printf '%s' "$cmd" | grep -Eiq 'empty' \
      && printf '%s' "$cmd" | grep -Eiq 'trash' \
      && deny "emptying the Trash via osascript is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])sudo([[:space:]]|$)' \
      && deny "sudo is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])dd[[:space:]]+' \
      && deny "dd is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])mkfs' \
      && deny "mkfs is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])ch(mod|own)[[:space:]]+(-[^[:space:]]*R|--recursive)' \
      && deny "recursive chmod/chown is not allowed"
    printf '%s' "$cmd" | grep -Eq ':[[:space:]]*\([[:space:]]*\)[[:space:]]*\{' \
      && deny "fork bomb pattern is not allowed"
    printf '%s' "$cmd" | grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh)' \
      && deny "piping a download straight into a shell is not allowed"
    printf '%s' "$cmd" | grep -Eq '>[[:space:]]*/dev/[a-z]' \
      && deny "redirecting to a device file is not allowed"

    # --- destructive / remote git ---
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git[[:space:]]+([^;&|]*[[:space:]])?reset[[:space:]]+([^;&|]*[[:space:]])?--hard' \
      && deny "git reset --hard is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git[[:space:]]+([^;&|]*[[:space:]])?clean[[:space:]]+-[^[:space:]]*f' \
      && deny "git clean -f is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git[[:space:]]+([^;&|]*[[:space:]])?(rebase|filter-branch|filter-repo)' \
      && deny "git rebase/filter-branch is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git[[:space:]]+([^;&|]*[[:space:]])?reflog[[:space:]]+expire' \
      && deny "git reflog expire is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git[[:space:]]+([^;&|]*[[:space:]])?gc([[:space:]]|$).*--prune' \
      && deny "git gc --prune is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git[[:space:]]+([^;&|]*[[:space:]])?branch[[:space:]]+([^;&|]*[[:space:]])?-D' \
      && deny "git branch -D (force delete) is not allowed"
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git[[:space:]]+(checkout|restore)[[:space:]]+([^;&|]*[[:space:]])?\.([[:space:]]|$)' \
      && deny "git checkout/restore . (discards changes) is not allowed"

    # --- commits are allowed, but never with a co-author trailer ---
    printf '%s' "$cmd" | grep -Eiq 'git[[:space:]]+commit' \
      && printf '%s' "$cmd" | grep -Eiq 'co-authored-by' \
      && deny "commits must be authored solely by Landon (no Co-Authored-By)"
    exit 0
    ;;

  Write | Edit | MultiEdit | NotebookEdit)
    path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [ -z "$path" ] && exit 0
    path_protected "$path" && deny "writing to a submodule or build output is not allowed: $path"
    exit 0
    ;;

  *)
    exit 0
    ;;
esac
