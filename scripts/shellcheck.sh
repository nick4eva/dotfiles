#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:=0.8.0}"

do_install() {
	if [[ "$(shellcheck --version 2>/dev/null)" == *"${SHELLCHECK_VERSION}"* ]]; then
		info "[shellcheck] ${SHELLCHECK_VERSION} already installed"
		return
	fi

	info "[shellcheck] Install ${SHELLCHECK_VERSION}"
	local shellcheck_tmp=/tmp/shellcheck.tar.xz
	local shellcheck=/usr/local/bin/shellcheck
	sudo rm -rf "${shellcheck_tmp}"
	download "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" "${shellcheck_tmp}"
	tar -xf "${shellcheck_tmp}" -C /tmp
	sudo mv "/tmp/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "${shellcheck}"
	sudo chmod +x "${shellcheck}"
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
