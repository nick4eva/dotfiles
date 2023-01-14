#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

LSD_VERSION="${LSD_VERSION:=0.23.1}"

do_install() {
	if [[ "$(lsd --version 2>/dev/null)" == *"${LSD_VERSION}"* ]]; then
		info "[lsd] ${LSD_VERSION} already installed"
		return
	fi

	info "[lsd] Install ${LSD_VERSION}"
	local lsd=/tmp/lsd.deb
	sudo rm -rf "${lsd}"
	download "https://github.com/Peltoche/lsd/releases/download/${LSD_VERSION}/lsd_${LSD_VERSION}_amd64.deb" "${lsd}"
	sudo dpkg -i "${lsd}"
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
