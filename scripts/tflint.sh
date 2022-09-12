#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

TFLINT_VERSION="${TFLINT_VERSION:=0.40.0}"

do_install() {
	if is_installed tflint; then
		info "[tflint] Already installed"
		return
	fi

	info "[tflint] Install"
	local tflint_tmp=/tmp/tflint.zip
	local tflint=/usr/local/bin/tflint
	download "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" "${tflint_tmp}"
	unzip "${tflint_tmp}" -d /tmp
	sudo mv /tmp/tflint "${tflint}"
	sudo chmod +x "${tflint}"
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
