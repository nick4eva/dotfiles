#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

RIPGREP_VERSION="${RIPGREP_VERSION:=13.0.0}"

do_install() {
	if [[ "$(ripgrep --version 2>/dev/null)" == *"${RIPGREP_VERSION}"* ]]; then
		info "[ripgrep] ${RIPGREP_VERSION} already installed"
		return
	fi

	info "[ripgrep] Install ${RIPGREP_VERSION}"
	local ripgrep=/tmp/ripgrep.deb
	sudo rm -rf "${ripgrep}"
	download "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep_${RIPGREP_VERSION}_amd64.deb" "${ripgrep}"
	sudo dpkg -i "${ripgrep}"
}

main() {
	command=$1
	case $command in
	"install")
		shift
		do_install "$@"
		;;
	*)
		error "$(basename "$0"): '$command' is not a valid command"
		;;
	esac
}

main "$@"
