#!/usr/bin/env zsh
# tmux integration for interactive shells.
#
# Switches (set to 0 in ~/dotfiles/zsh/extras or ~/.zshenv to turn a part off):
#   DOTFILES_TMUX_AUTOSTART  attach to (or create) the "default" session when a terminal opens
#   DOTFILES_TMUX_RENAME     name windows "dir" when idle and "cmd(dir)" while a command runs
#
# Optional: tmux-tools (https://github.com/raine/tmux-tools) for `cch`:
#   git clone https://github.com/raine/tmux-tools.git ~/.tmux-tools

# Only a newly opened terminal attaches: not `zsh -ic 'cmd'`, not a shell without a terminal.
# Terminals embedded in editors get their own shell, not the shared tmux session.
_tmux_autostart_allowed() {
  [[ -o interactive && -z "${TMUX}" && -z "${ZSH_EXECUTION_STRING}" ]] || return 1
  [[ -t 0 && -t 1 ]] || return 1
  [[ "${TERM_PROGRAM}" != "vscode" && "${TERM_PROGRAM}" != "kiro" ]] || return 1
  [[ "${TERMINAL_EMULATOR}" != "JetBrains-JediTerm" ]]
}

# Name of the command a command line runs, without wrappers and their options:
# "sudo -u root apt update" -> "apt", "  ./bin/run.sh x" -> "run.sh"
_tmux_command_name() {
  local -a words=(${(z)1})
  local word wrapper=""
  while (( $#words )); do
    word="${words[1]}"
    if [[ "$word" == (sudo|noglob|nocorrect|command|builtin|exec|nohup|time) ]]; then
      wrapper="$word"
    elif [[ -n "$wrapper" && "$word" == -* ]]; then
      # sudo options that take a value: skip the value as well
      [[ "$wrapper" == sudo && "$word" == -[ugCDhpRrTt] ]] && shift words
    elif [[ "$word" != *=* ]]; then
      break
    fi
    shift words
  done
  print -r -- "${${words[1]:-}:t}"
}

# -t "$TMUX_PANE": rename the window this shell runs in, not the one in focus
_tmux_rename_preexec() {
  tmux rename-window -t "${TMUX_PANE}" "$(_tmux_command_name "$1")(${(%):-%1~})"
  # Re-enable automatic-rename so tmux tracks sub-processes
  # (e.g., cc-history launching claude)
  tmux set-window-option -t "${TMUX_PANE}" automatic-rename on
}

_tmux_rename_precmd() {
  tmux rename-window -t "${TMUX_PANE}" "${(%):-%1~}"
}

tmux_shell_integration() {
  (( $+commands[tmux] )) || return 0

  if [[ -d "$HOME/.tmux-tools" ]]; then
    path+=("$HOME/.tmux-tools")
    # Launch/attach a dedicated "claude-<hash>" tmux session for $PWD (session-per-Claude
    # workflow); same session as tmux-claude-hatch's `prefix + A`. Works in or out of tmux.
    alias cch='claude-hatch-session'
  fi

  if [[ -n "${TMUX}" && "${DOTFILES_TMUX_RENAME:-1}" != 0 ]]; then
    # oh-my-zsh would overwrite the window name with its own terminal title
    export DISABLE_AUTO_TITLE='true'
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec _tmux_rename_preexec
    add-zsh-hook precmd _tmux_rename_precmd
  fi

  if [[ "${DOTFILES_TMUX_AUTOSTART:-1}" != 0 ]] && _tmux_autostart_allowed; then
    # -A: attach when "default" exists, otherwise create it
    tmux new-session -A -s default
  fi
}

tmux_shell_integration
