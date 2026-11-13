#!/usr/bin/env zsh
# jot: a friction log. Note what slows you down while you work, review it later.
#
#   jot <note>   log a note (with no note: show the log)
#   jotl         list open notes with line numbers
#   jotd <n>     mark note n done (moves it to the completed log)
#   jotc         list completed notes
#
# Every FRICTION_REMINDER_INTERVAL seconds the prompt prints a one-line reminder;
# logging a note resets the timer.
FRICTION_REMINDER_INTERVAL="${FRICTION_REMINDER_INTERVAL:-3600}"  # seconds (default: 1 hour)
FRICTION_REMINDER_FILE="${FRICTION_REMINDER_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/friction_last_reminder}"
FRICTION_LOG_FILE="${FRICTION_LOG_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/friction.log}"
FRICTION_DONE_FILE="${FRICTION_DONE_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/friction-completed.log}"

# Ensure dirs exist
mkdir -p "$(dirname "$FRICTION_REMINDER_FILE")"
mkdir -p "$(dirname "$FRICTION_LOG_FILE")"

# Initialize timestamp file if missing
[[ -f "$FRICTION_REMINDER_FILE" ]] || date +%s > "$FRICTION_REMINDER_FILE"

_friction_check() {
  local now last elapsed
  now=$(date +%s)
  last=$(command cat "$FRICTION_REMINDER_FILE" 2>/dev/null || echo 0)
  elapsed=$(( now - last ))

  if (( elapsed >= FRICTION_REMINDER_INTERVAL )); then
    local count=0
    [[ -f "$FRICTION_LOG_FILE" ]] && count=$(wc -l < "$FRICTION_LOG_FILE")
    # Dim yellow, non-intrusive
    printf '\033[33m💡 Hit any friction? Remember: jot "your note here" (%d items logged)\033[0m\n' "$count"
    echo "$now" > "$FRICTION_REMINDER_FILE"
  fi
}

# The jot function — logs friction and resets reminder timer
jot() {
  if [[ -z "$*" ]]; then
    echo "Usage: jot <description of friction>"
    echo "Log: $FRICTION_LOG_FILE"
    [[ -f "$FRICTION_LOG_FILE" ]] && echo "---" && command cat "$FRICTION_LOG_FILE"
    return
  fi
  # One note per line: jotl and jotd number notes by line
  local note="${*//$'\n'/ }"
  if ! print -r -- "$(date +%Y-%m-%d\ %H:%M) ${note}" >> "$FRICTION_LOG_FILE"; then
    printf '\033[31m✗ Could not write to %s\033[0m\n' "$FRICTION_LOG_FILE" >&2
    return 1
  fi
  date +%s > "$FRICTION_REMINDER_FILE"
  printf '\033[32m✓ Logged: %s\033[0m\n' "$note"
}

# Review/manage friction log
jotl() {
  if [[ ! -f "$FRICTION_LOG_FILE" ]] || [[ ! -s "$FRICTION_LOG_FILE" ]]; then
    echo "Friction log is empty 🎉"
    return
  fi
  command cat -n "$FRICTION_LOG_FILE"
}

# Complete a resolved item by line number — moves it to FRICTION_DONE_FILE
jotd() {
  if [[ "$1" != <-> ]]; then
    echo "Usage: jotd <line_number>"
    return 1
  fi
  local entry=""
  [[ -f "$FRICTION_LOG_FILE" ]] && entry=$(sed -n "${1}p" "$FRICTION_LOG_FILE")
  if [[ -z "$entry" ]]; then
    echo "No item #$1 in $FRICTION_LOG_FILE"
    return 1
  fi
  # Archive first; remove the note only once it is archived. The temp file keeps the
  # log intact if the rewrite fails (and works with BSD sed, which has no plain -i).
  if ! print -r -- "done $(date +%Y-%m-%d\ %H:%M) | $entry" >> "$FRICTION_DONE_FILE"; then
    printf '\033[31m✗ Could not write to %s; note #%s kept\033[0m\n' "$FRICTION_DONE_FILE" "$1" >&2
    return 1
  fi
  if ! { sed "${1}d" "$FRICTION_LOG_FILE" > "$FRICTION_LOG_FILE.tmp" && mv "$FRICTION_LOG_FILE.tmp" "$FRICTION_LOG_FILE"; }; then
    rm -f "$FRICTION_LOG_FILE.tmp"
    printf '\033[31m✗ Archived note #%s but could not remove it from %s\033[0m\n' "$1" "$FRICTION_LOG_FILE" >&2
    return 1
  fi
  printf '\033[32m✓ Completed #%s: %s\033[0m (moved to %s)\n' "$1" "$entry" "$FRICTION_DONE_FILE"
}

# Review completed items
jotc() {
  if [[ ! -f "$FRICTION_DONE_FILE" ]] || [[ ! -s "$FRICTION_DONE_FILE" ]]; then
    echo "No completed items yet"
    return
  fi
  command cat -n "$FRICTION_DONE_FILE"
}

# Check on every prompt
autoload -Uz add-zsh-hook
add-zsh-hook precmd _friction_check
