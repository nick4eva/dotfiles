#!/usr/bin/env zsh
# vim: set filetype=zsh

runc() {
  export FZF_DEFAULT_OPTS='--height 90% --reverse --border'
  local image=$(docker images --format '{{.Repository}}:{{.Tag}}' | fzf --reverse --multi)
  if [[ $image != '' ]]; then
    echo -e "\n  \033[1mDocker image:\033[0m" $image
    read -e -p $'  \e[1mOptions: \e[0m' -i "-it --rm" options

    printf "  \033[1mChoose the command: \033[0m"
    local cmd=$(echo -e "/bin/bash\nsh" | fzf --reverse --multi)
    if [[ $cmd == '' ]]; then
        read -e -p $'  \e[1mCustom command: \e[0m' cmd
    fi
    echo -e "  \033[1mCommand: \033[0m" $cmd

    export FZF_DEFAULT_COMMAND='find ./ -type d -maxdepth 1 -exec basename {} \;'
    printf "  \033[1mChoose the volume: \033[0m"
    local volume=$(fzf --reverse --multi)
    local curDir=${PWD##*/}
    if [[ $volume == '.' ]]; then
        echo -e "  \033[1mVolume: \033[0m" $volume
        volume="`pwd`:/$curDir -w /$curDir"
    else
        echo -e "  \033[1mVolume: \033[0m" $volume
        volume="`pwd`/$volume:/$volume -w /$volume"
    fi

    export FZF_DEFAULT_COMMAND=""
    export FZF_DEFAULT_OPTS=""

    history -s runc
    history -s docker run $options -v $volume $image $cmd
    echo ''
    docker run $options -v $volume $image $cmd
  fi
}

# Prints the registry file of the live claude process that holds a session, matched by
# session id or by name ("X" also matches "X (2)"). Live means the pid runs and started
# when the registry says (procStart = field 22 of /proc/<pid>/stat), so a reused pid
# doesn't count.
_claude_session_holder() {
  local target=$1 f pid started
  for f in ~/.claude/sessions/<->.json(N); do
    pid=${${f:t}%.json}
    [[ -r /proc/$pid/stat ]] || continue
    started=${${(s: :)${"$(</proc/$pid/stat)"##*) }}[20]}
    jq -e --arg t "$target" --arg started "$started" '
      select((.procStart | tostring) == $started)
      | select(.sessionId == $t or .name == $t
               or ((.name // "") | sub(" \\([0-9]+\\)$"; "")) == $t)' "$f" >/dev/null 2>&1 || continue
    print -r -- "$f"
    return 0
  done
  return 1
}

# Refuses `claude --resume <id|name>` and `claude --continue` when another live claude
# process holds that session: Claude Code would fork it into a copy with a new id and a
# " (N)" name. Offers to switch to the holder's tmux pane instead.
# Bypass: --fork-session, or CLAUDE_ALLOW_FORK=1. Not covered: the bare -r picker, /resume.
_claude_resume_guard() {
  [[ -n $CLAUDE_ALLOW_FORK ]] && return 0
  local target='' arg prev='' newest
  for arg in "$@"; do
    case $arg in
      --fork-session) return 0 ;;
      --resume=*) target=${arg#--resume=} ;;
      -c|--continue)
        newest=( ~/.claude/projects/${PWD//[^A-Za-z0-9]/-}/*.jsonl(N.om[1]) )
        (( $#newest )) && target=${${newest[1]:t}%.jsonl} ;;
      -*) ;;
      *) [[ $prev == (-r|--resume) ]] && target=$arg ;;
    esac
    prev=$arg
  done
  [[ -z $target ]] && return 0

  local holder pane
  holder=$(_claude_session_holder "$target") || return 0
  pane=$(jq -r '.tmux // "" | sub("^.*\\."; "")' "$holder")
  jq -r '"claude: session \"\(.name // "-")\" (\(.sessionId)) is live in pid \(.pid), \(.status // "?"), tmux \(.tmux // "none")\nResuming it here would fork a copy. Use --fork-session or CLAUDE_ALLOW_FORK=1 if you want one."' "$holder" >&2
  if [[ -n $TMUX && -n $pane && -t 0 ]]; then
    local answer
    read -q "answer?Switch to it? [y/N] " </dev/tty
    print >&2
    [[ $answer == y ]] && tmux switch-client -t "$pane"
  fi
  return 1
}

claude() {
  _claude_resume_guard "$@" || return 1
  if command -v repomix &>/dev/null && [ ! -f repomix-output.xml ]; then
    echo "repomix: packing codebase..."
    echo
    repomix --compress --output repomix-output.xml --quiet 2>/dev/null
  fi
  command claude "$@"
}
