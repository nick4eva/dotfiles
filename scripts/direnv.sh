#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_configure() {
    info "[direnv] Configure"
    info "[direnv][configure] Create config file symlink"
    mkdir -p "${XDG_CONFIG_HOME}/direnv"
    ln -fs "$(pwd)/direnv/direnv.toml" "${XDG_CONFIG_HOME}/direnv/direnv.toml"
}

main() {
    command=$1
    case $command in
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
