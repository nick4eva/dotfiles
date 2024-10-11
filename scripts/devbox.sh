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
	DEVBOX_GLOBAL_DIR="$HOME/.local/share/devbox/global/default"
	mkdir -p "$DEVBOX_GLOBAL_DIR"
	info "[devbox][configure] Create symlinks"
	ln -fs "$(pwd)/devbox/devbox.json" "$DEVBOX_GLOBAL_DIR/devbox.json"
	# echo "eval '$(devbox global shellenv)'" >> ~/.zshrc
	# source ~/.zshrc
	# temporarily add the global packages to the current shell (this is already configured in oh-my-zsh)
	source <(devbox global shellenv --init-hook)
	devbox global install
	refresh-global
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
