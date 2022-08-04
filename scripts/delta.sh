#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

DELTA_VERSION="${DELTA_VERSION:=0.13.0}"

do_install() {
	if [[ "$(delta --version 2>/dev/null)" == *"${DELTA_VERSION}"* ]]; then
		info "[delta] ${DELTA_VERSION} already installed"
		return
	fi

	info "[delta] Install ${DELTA_VERSION}"
	local delta=/tmp/delta.deb
	download "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb" "${delta}"
	sudo dpkg -i "${delta}"
}

do_configure() {
	info "[delta] Configure"
	info "[delta][configure] Create config file symlink"
	ln -fs "$(pwd)/delta/gitconfig-delta" "${HOME}/.gitconfig"
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
