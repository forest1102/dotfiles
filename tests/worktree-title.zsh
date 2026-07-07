#!/usr/bin/env zsh
emulate -L zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SCRIPT="$ROOT/modules/home/worktree-title.zsh"
TMP="${TMPDIR:-/tmp}/worktree-title-test.$$"
mkdir -p "$TMP/bin"
trap 'rm -rf "$TMP"' EXIT

export PATH="$TMP/bin:$PATH"
export WORKTREE_TITLE_TEST_LOG="$TMP/log"
export TEST_BRANCH="feature/example"
export GH_PR_VIEW_STATE="open"
export GH_PR_VIEW_STATUS="0"
export GH_CREATE_STATUS="0"

cat > "$TMP/bin/git" <<'STUB'
#!/usr/bin/env zsh
if [[ "$1" == "branch" && "$2" == "--show-current" ]]; then
  print -r -- "${TEST_BRANCH:-}"
  exit 0
fi
exit 1
STUB
chmod +x "$TMP/bin/git"

cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env zsh
print -r -- "gh|$*" >> "$WORKTREE_TITLE_TEST_LOG"
if [[ "$1" == "pr" && "$2" == "create" ]]; then
  print -r -- "created"
  exit "${GH_CREATE_STATUS:-0}"
fi
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "${GH_PR_VIEW_STATUS:-0}" == "0" ]]; then
    print -r -- "${GH_PR_VIEW_STATE:-open}"
  else
    print -r -- "${GH_PR_VIEW_ERROR:-no pull requests found for branch}"
  fi
  exit "${GH_PR_VIEW_STATUS:-0}"
fi
exit 0
STUB
chmod +x "$TMP/bin/gh"

cat > "$TMP/bin/tmux" <<'STUB'
#!/usr/bin/env zsh
line="tmux"
for arg in "$@"; do
  line="$line|$arg"
done
print -r -- "$line" >> "$WORKTREE_TITLE_TEST_LOG"
STUB
chmod +x "$TMP/bin/tmux"

assert_log_contains() {
  local expected="$1"
  if ! grep -Fqx "$expected" "$WORKTREE_TITLE_TEST_LOG"; then
    print -ru2 -- "missing log line: $expected"
    print -ru2 -- "--- log ---"
    cat "$WORKTREE_TITLE_TEST_LOG" >&2 || true
    exit 1
  fi
}

assert_log_not_contains_prefix() {
  local unexpected="$1"
  if grep -Fq "$unexpected" "$WORKTREE_TITLE_TEST_LOG"; then
    print -ru2 -- "unexpected log prefix: $unexpected"
    print -ru2 -- "--- log ---"
    cat "$WORKTREE_TITLE_TEST_LOG" >&2 || true
    exit 1
  fi
}

: > "$WORKTREE_TITLE_TEST_LOG"
source "$SCRIPT"

export TMUX="tmux-session"
worktree-title-refresh >/dev/null
assert_log_contains "tmux|rename-window|[open] feature/example"
assert_log_contains "tmux|set-window-option|-q|@worktree_pr_state|open"
assert_log_contains "tmux|set-window-option|-q|@worktree_pr_color|green"
assert_log_contains "tmux|set-option|-gq|@worktree_pr_title_format_installed|1"
assert_log_contains "tmux|set-option|-gq|window-status-format|#{?#{@worktree_pr_color},#[fg=#{@worktree_pr_color}],}#I:#W#[default]"

: > "$WORKTREE_TITLE_TEST_LOG"
GH_PR_VIEW_STATE="draft"
worktree-title-refresh >/dev/null
assert_log_contains "tmux|rename-window|[draft] feature/example"
assert_log_contains "tmux|set-window-option|-q|@worktree_pr_color|yellow"

: > "$WORKTREE_TITLE_TEST_LOG"
GH_PR_VIEW_STATUS="1"
GH_PR_VIEW_ERROR="no pull requests found for branch"
worktree-title-refresh >/dev/null
assert_log_contains "tmux|rename-window|[no-pr] feature/example"
assert_log_contains "tmux|set-window-option|-q|@worktree_pr_color|default"

: > "$WORKTREE_TITLE_TEST_LOG"
GH_PR_VIEW_STATUS="0"
GH_PR_VIEW_STATE="open"
GH_CREATE_STATUS="0"
output="$(gh pr create --fill)"
exit_status="$?"
[[ "$exit_status" == "0" ]]
[[ "$output" == "created" ]]
assert_log_contains "gh|pr create --fill"
assert_log_contains "tmux|rename-window|[open] feature/example"

: > "$WORKTREE_TITLE_TEST_LOG"
GH_CREATE_STATUS="7"
set +e
gh pr create --fill >/dev/null
exit_status="$?"
set -e
[[ "$exit_status" == "7" ]]
assert_log_contains "gh|pr create --fill"
assert_log_not_contains_prefix "tmux|rename-window"
