#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_configure() {
	info "[starship] Configure"
	info "[starship][configure] Create config files symlinks"
	ln -fs "$(pwd)/starship/starship.toml" "${XDG_CONFIG_HOME}/starship.toml"
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
