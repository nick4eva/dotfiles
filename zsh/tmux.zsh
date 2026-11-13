# tmux integration for interactive shells.
#
# Switches (set to 0 in ~/dotfiles/zsh/extras or ~/.zshenv to turn a part off):
#   DOTFILES_TMUX_AUTOSTART  attach to (or create) the "default" session when a terminal opens
#   DOTFILES_TMUX_RENAME     name windows "dir" when idle and "cmd(dir)" while a command runs
#
# Optional: tmux-tools (https://github.com/raine/tmux-tools) for `cch`:
#   git clone https://github.com/raine/tmux-tools.git ~/.tmux-tools

# Terminals embedded in editors get their own shell, not the shared tmux session
_tmux_autostart_allowed() {
  [[ -o interactive && -z "${TMUX}" ]] || return 1
  [[ "${TERM_PROGRAM}" != "vscode" && "${TERM_PROGRAM}" != "kiro" ]] || return 1
  [[ "${TERMINAL_EMULATOR}" != "JetBrains-JediTerm" ]]
}

_tmux_rename_preexec() {
  local cmd="${1%% *}"
  # Show the actual command, not wrappers like sudo/noglob
  case "$cmd" in
    sudo|noglob|nocorrect|command|builtin|exec) cmd="${1#* }"; cmd="${cmd%% *}" ;;
  esac
  tmux rename-window "${cmd}($(basename "$PWD"))"
  # Re-enable automatic-rename so tmux tracks sub-processes
  # (e.g., cc-history launching claude)
  tmux set-window-option automatic-rename on
}

_tmux_rename_precmd() {
  tmux rename-window "$(basename "$PWD")"
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
    tmux attach-session -t default || tmux new-session -s default
  fi
}

tmux_shell_integration
