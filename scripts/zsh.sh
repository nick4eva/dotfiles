#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_configure() {
	info "[zsh] Install"
	sudo apt-get install -qq -y zsh
	info "[zsh] Configure"
	info "[zsh][configure] Create empty config if config is missing"
	# TODO add check to create empty config only if config is missing
	echo "# Empty config created by dotfiles (will be replaced by oh-my-zsh)" >> ~/.zshrc
	info "[zsh][configure] Set as default shell"
	chsh -s "$(which zsh)"
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
