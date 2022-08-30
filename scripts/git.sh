#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_configure() {
	info "[git] Configure"
	info "[git][configure] Create config files symlinks"
	mkdir -p "${XDG_CONFIG_HOME}/git"
	ln -fs "$(pwd)/git/gitconfig" "${HOME}/.gitconfig"
	ln -fs "$(pwd)/git/aliases.ini" "${XDG_CONFIG_HOME}/git/aliases.ini"

	info "[git][configure] Create a commit-template file"
	touch "$(pwd)/git/commit-template"
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
