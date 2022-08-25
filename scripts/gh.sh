#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

GH_VERSION="${GH_VERSION:=2.14.7}"

do_install() {
	if [[ "$(gh --version 2>/dev/null)" == *"${GH_VERSION}"* ]]; then
		info "[gh] ${GH_VERSION} already installed"
		return
	fi

	info "[gh] Install ${GH_VERSION}"
	local gh=/tmp/gh.deb
	sudo rm -rf "${gh}"
	download "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.deb" "${gh}"
	sudo dpkg -i "${gh}"
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
