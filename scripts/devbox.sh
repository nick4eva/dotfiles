#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_install() {
	if is_installed devbox; then
		info "[devbox] Already installed. To update use: devbox version update"
		return
	fi

	info "[devbox] Install"
	bash -c "$(curl -fsSL https://get.jetify.com/devbox)" "" --force
}

do_configure() {
	info "[devbox] Configure"
	info "[devbox][configure] Create dir"
	mkdir -p "$HOME/.local/share/devbox/global/default"
	info "[devbox][configure] Create symlinks"
	ln -fs "$(pwd)/devbox/devbox.json" "$HOME/.local/share/devbox/global/default/devbox.json"
	devbox global install
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
