#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_configure() {
	info "[delta] Configure"
	info "[delta][configure] Create config file symlink"
	ln -fs "$(pwd)/delta/gitconfig-delta.ini" "${HOME}/.gitconfig"
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
