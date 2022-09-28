#!/usr/bin/env bash

set -e

# asdf source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

ASDF_VERSION="${ASDF_VERSION:=0.10.2}"

do_install() {
	if [[ "$(asdf --version 2>/dev/null)" == *"${ASDF_VERSION}"* ]]; then
		info "[asdf] ${ASDF_VERSION} already installed"
		return
	fi

	info "[asdf] Install ${ASDF_VERSION}"
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v"${ASDF_VERSION}"
}

do_configure() {
	info "[asdf] Configure"
	source "${HOME}/.asdf/asdf.sh"
	info "[asdf][configure] Create config file symlink"
	ln -fs "$(pwd)/asdf/tool-versions" "${HOME}/.tool-versions"
	info "[asdf][configure] Add plugins"
	asdf plugin add deno
	asdf plugin add github-cli
	asdf plugin add act
	asdf plugin add bat
	asdf plugin add delta
	info "[asdf][configure] Installing tools"
	asdf install
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
