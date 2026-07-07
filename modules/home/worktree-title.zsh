__worktree_title_branch() {
  command git branch --show-current 2>/dev/null
}

__worktree_title_pr_state() {
  local output
  if output="$(
    command gh pr view \
      --json state,isDraft \
      --jq 'if .isDraft then "draft" else (.state | ascii_downcase) end' 2>&1
  )"; then
    case "$output" in
      draft|open|merged|closed) print -r -- "$output" ;;
      *) print -r -- "unknown" ;;
    esac
    return 0
  fi

  case "${output:l}" in
    *"no pull request"*|*"no pull requests"*|*"not found"*) print -r -- "no-pr" ;;
    *) print -r -- "unknown" ;;
  esac
}

__worktree_title_state_color() {
  case "$1" in
    open) print -r -- "green" ;;
    draft) print -r -- "yellow" ;;
    merged) print -r -- "cyan" ;;
    closed) print -r -- "red" ;;
    unknown) print -r -- "blue" ;;
    *) print -r -- "default" ;;
  esac
}

__worktree_title_clean() {
  print -r -- "${1//$'\n'/ }" | tr -d '\r\a'
}

__worktree_title_set_terminal_title() {
  local title
  title="$(__worktree_title_clean "$1")"

  if [[ -t 1 && -w /dev/tty ]]; then
    print -rn -- $'\e]0;'"$title"$'\a' > /dev/tty 2>/dev/null || true
  fi
}

__worktree_title_set_tmux_window() {
  local title="$1"
  local state="$2"
  local color="$3"

  [[ -n "${TMUX:-}" ]] || return 0
  command tmux set-option -gq @worktree_pr_title_format_installed 1 2>/dev/null || true
  command tmux set-option -gq \
    window-status-format \
    '#{?#{@worktree_pr_color},#[fg=#{@worktree_pr_color}],}#I:#W#[default]' 2>/dev/null || true
  command tmux set-option -gq \
    window-status-current-format \
    '#{?#{@worktree_pr_color},#[bold,fg=#{@worktree_pr_color}],#[bold]}#I:#W#[default]' 2>/dev/null || true
  command tmux rename-window "$title" 2>/dev/null || true
  command tmux set-window-option -q @worktree_pr_state "$state" 2>/dev/null || true
  command tmux set-window-option -q @worktree_pr_color "$color" 2>/dev/null || true
}

worktree-title-refresh() {
  local branch state color title
  branch="$(__worktree_title_branch)"

  if [[ -z "$branch" ]]; then
    return 1
  fi

  state="$(__worktree_title_pr_state)"
  color="$(__worktree_title_state_color "$state")"
  title="[$state] $branch"

  __worktree_title_set_terminal_title "$title"
  __worktree_title_set_tmux_window "$title" "$state" "$color"
}

gh() {
  command gh "$@"
  local exit_status="$?"

  if [[ "$exit_status" == "0" && "${1:-}" == "pr" && "${2:-}" == "create" ]]; then
    worktree-title-refresh || true
  fi

  return "$exit_status"
}
