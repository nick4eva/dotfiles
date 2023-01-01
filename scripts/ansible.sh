#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

ANSIBLE_CORE_VERSION="${ANSIBLE_CORE_VERSION:=2.12.10}"

do_install() {
	if [[ "$(ansible --version 2>/dev/null)" == *"${ANSIBLE_CORE_VERSION}"* ]]; then
		info "[ansible] ${ANSIBLE_CORE_VERSION} already installed"
		return
	fi

	info "[ansible] Install ${ANSIBLE_CORE_VERSION}"
	python3 -m pip install --user ansible-core=="${ANSIBLE_CORE_VERSION}"
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
