#!/usr/bin/env bash

set -e

# ansible source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

ANSIBLE_LINT_VERSION="${ANSIBLE_LINT_VERSION:=6.8.2}"

do_install() {
	if [[ "$(ansible-lint --version 2>/dev/null)" == *"${ANSIBLE_LINT_VERSION}"* ]]; then
		info "[ansible-lint] ${ANSIBLE_LINT_VERSION} already installed"
		return
	fi

	info "[ansible-lint] Install ${ANSIBLE_LINT_VERSION}"
	python3 -m pip install --user ansible-lint=="${ANSIBLE_LINT_VERSION}"
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
