#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

NAVI_VERSION="${NAVI_VERSION:=2.20.1}"

do_install() {
	if [[ "$(navi --version 2>/dev/null)" == *"${NAVI_VERSION}"* ]]; then
		info "[navi] ${NAVI_VERSION} already installed"
		return
	fi

	info "[navi] Install ${NAVI_VERSION}"
	local navi_tmp=/tmp/navi.tar.gz
	local navi=/usr/local/bin/navi
	sudo rm -rf "${navi_tmp}"
	download "https://github.com/denisidoro/navi/releases/download/v${NAVI_VERSION}/navi-v${NAVI_VERSION}-x86_64-unknown-linux-musl.tar.gz" ${navi_tmp}
	tar -xf "${navi_tmp}" -C /tmp
	sudo mv "/tmp/navi" "${navi}"
	sudo chmod +x "${navi}"
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
