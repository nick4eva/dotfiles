#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

TFSEC_VERSION="${TFSEC_VERSION:=1.27.0}"

do_install() {
	if is_installed tfsec; then
		info "[tfsec] Already installed"
		return
	fi

	info "[tfsec] Install"
	local tfsec_tmp=/tmp/tfsec
	local tfsec=/usr/local/bin/tfsec
	download "https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64" "${tfsec_tmp}"
	sudo mv "${tfsec_tmp}" "${tfsec}"
	sudo chmod +x "${tfsec}"
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
