#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_configure() {
	info "[bat] Configure"
	info "[bat][configure] Create config file symlink"
	mkdir -p "${XDG_CONFIG_HOME}/bat"
	ln -fs "$(pwd)/bat/config" "${XDG_CONFIG_HOME}/bat/config"
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
