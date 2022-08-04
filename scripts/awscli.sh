#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_install() {
	if is_installed aws; then
		info "[awscli] Already installed"
		return
	fi

	info "[awswcli] Install"
	local awscli=/tmp/awscliv2.zip
	download "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" "${awscli}"
	unzip "${awscli}"
	sudo /tmp/aws/install
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
