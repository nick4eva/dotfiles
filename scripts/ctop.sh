#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

CTOP_VERSION="${CTOP_VERSION:=0.7.7}"

do_install() {
	if is_installed ctop; then
		info "[ctop] Already installed"
		return
	fi

	info "[ctop] Install"
	local ctop_tmp=/tmp/ctop
	local ctop=/usr/local/bin/ctop
	download "https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-amd64" "${ctop_tmp}"
	sudo mv "${ctop_tmp}" "${ctop}"
	sudo chmod +x "${ctop}"
}

do_configure() {
	info "[ctop] Configure"
	info "[ctop][configure] Create config file symlink"
	mkdir -p "${XDG_CONFIG_HOME}/ctop"
	ln -fs "$(pwd)/ctop/config" "${XDG_CONFIG_HOME}/ctop/config"
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
