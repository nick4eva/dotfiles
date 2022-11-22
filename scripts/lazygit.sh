#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_configure() {
	info "[lazygit] Configure"
	info "[lazygit][configure] Create config file symlink"
	ln -fs "$(pwd)/lazygit/config.yml" "${XDG_CONFIG_HOME}/lazygit/config.yml"
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
