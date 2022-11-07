#!/usr/bin/env zsh
# vim: set filetype=zsh

function cmd_path () {
    if [[ ${ZSH_VERSION} ]]; then
        whence -cp "$1" > /dev/null 2>&1
    else  # bash
        type -P "$1" > /dev/null 2>&1
    fi
}

# misc
if cmd_path lsd; then
    LS_OPTS="--color=always --long --group-dirs first"
    alias ls="lsd ${LS_OPTS}"
    alias lt="ls -t --reverse"
    alias la="ls -a"
else
    LS_OPTS="--color=auto --group-directories-first"
    alias ls="ls ${LS_OPTS} -lhA"
    alias lt="ls -ltrh"
    alias la="ls -A"
fi
alias ll='ls'

alias grepi="grep -i"
alias upd="${HOME}/dotfiles/scripts/update.sh"

# git
alias ggrep="git grep -n -I --break --heading -B0 -A0"
alias ggrepi="ggrep --ignore-case"
alias gu="git stash && git pull && git stash pop || true"

# docker
alias dps="docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.State}}\t{{.Status}}\""
alias dpse="docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}\t{{.Size}}\""

docker-clean() {
    docker container prune -f && docker volume prune -f && docker network prune -f
}

# aws
alias aws="aws --no-cli-pager"

# tldr
alias tldr="tldr --theme=base16"

# z with fzf
unalias z 2> /dev/null
z() {
  [ $# -gt 0 ] && _z "$*" && return
  cd "$(_z -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')" || return
}

# convert minutes {0..60} to {red..green} in hex
function _minutes_to_hex() {
    local num=$1
    local min=0
    local max=60
    local middle=$(((min + max) / 2))
    local scale=$((255.0 / (middle - min)))
    if [[ $num -le $min ]]; then local num=$min; fi
    if [[ $num -ge $max ]]; then local num=$max; fi
    if [[ $num -le $middle ]]; then
        printf "#ff%02x00\n" $(((num - min) * scale))
    else
        printf "#%02xff00\n" $((255 - ((num - middle) * scale)))
    fi
}

alias cls="clear"
alias c="code ."
alias dc="devcontainer ."
alias fd="fdfind"
alias pr="gh pr create --fill"
alias prw="gh pr create --fill && gh pr checks --watch --interval 5"
alias checks="gh pr checks --watch --interval 5"
alias deploy="gh pr comment -b 'deploy'"
alias plan="gh pr comment -b 'plan'"
alias apply="gh pr comment -b 'apply'"
alias up="gcm && gl"
alias ctop="nocorrect ctop"
alias prm="gh pr merge -m -d"
