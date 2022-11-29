#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

WIN32YANK_VERSION="${WIN32YANK_VERSION:=0.0.4}"

do_install() {
	if is_installed win32yank.exe; then
		info "[win32yank] Already installed"
		return
	fi

	info "[win32yank] Install"
	local win32yank_tmp=/tmp/win32yank.zip
	local win32yank_exe=/tmp/win32yank.exe
	download "https://github.com/equalsraf/win32yank/releases/download/v${WIN32YANK_VERSION}/win32yank-x64.zip" "${win32yank_tmp}"
	unzip -p "${win32yank_tmp}" win32yank.exe > "${win32yank_exe}"
	sudo chmod +x "${win32yank_exe}"
	sudo mv "${win32yank_exe}" /usr/local/bin/
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
