#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

OH_MY_TMUX="${OH_MY_TMUX:-${HOME}/src/personal/.tmux}"

do_install() {
    if [[ -d "${OH_MY_TMUX}" ]]; then
        info "[tmux] Oh my tmux! already installed"
        return
    fi

    info "[tmux] Install Oh my tmux!"
    git clone --quiet https://github.com/gpakosz/.tmux "${OH_MY_TMUX}"
}

do_configure() {
    info "[tmux] Configure"
    mkdir -p "${XDG_CONFIG_HOME}/tmux"

    info "[tmux][configure] Create config file symlinks"
    ln -fs "${OH_MY_TMUX}/.tmux.conf" "${XDG_CONFIG_HOME}/tmux/tmux.conf"
    ln -fs "$(pwd)/tmux/tmux.conf.local" "${XDG_CONFIG_HOME}/tmux/tmux.conf.local"
}

main() {
    command=$1
    case $command in
    "install")
        shift
        do_install "$@"
        ;;
    "configure")
        shift
        do_configure "$@"
        ;;
    *)
        error "$(basename "$0"): '$command' is not a valid command"
        ;;
    esac
}

main "$@"
