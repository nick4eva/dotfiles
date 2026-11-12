#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

FONTS_DIR="$HOME/.local/share/fonts"

do_install() {
	local packages=(
		build-essential
		curl
		fd-find
		fontconfig
		git
		jq
		tig
		tmux
		tree
		wget
		zsh
		unzip
		python3-pip
    stow
	)

	info "[system] Install packages"
	export DEBIAN_FRONTEND=noninteractive
	# Newer git from the PPA is optional: Launchpad is unreachable from some networks
	# (e.g. GitHub runners), where the lookup hangs ~7 min and then fails
	if ! sudo timeout 60 apt-add-repository -y ppa:git-core/ppa; then
		warn "[system] Could not add ppa:git-core/ppa, installing git from the Ubuntu archive"
	fi
	sudo apt-get update -qq
	sudo apt-get install -qq -y "${packages[@]}"
}

do_configure() {
	info "[system] Configure"
	info "[system][configure] Create directories"
	info "[system][configure][directories] Repositories"
	sudo install -d -m 0755 -o "${USER}" -g "${USER}" ~/src

	info "[system][configure][directories] User Fonts"
	install -d -m 0755 -o "${USER}" -g "${USER}" "${FONTS_DIR}"

	info "[system][configure][directories] User binaries directory"
	install -d -m 0755 -o "${USER}" -g "${USER}" "$HOME/bin"

	# Font: MesloLGL Nerd Font Mono
	# https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/Meslo/L/Regular/complete
	info "[system][configure] Install patched fonts"
	local install_dir="/tmp/nerd-fonts"
	sudo rm -rf "${install_dir}" && mkdir -p "${install_dir}"
	# Works with git 2.25 (focal without the git-core PPA): no `clone --sparse`, no `sparse-checkout add`
	git clone --quiet --filter=blob:none --no-checkout "https://github.com/ryanoasis/nerd-fonts.git" "${install_dir}"
	(
		cd "${install_dir}"
		git sparse-checkout init --cone
		git sparse-checkout set patched-fonts/Meslo/L/Regular
		git checkout --quiet
		find . -type f -name '*.ttf' ! -name '*Windows*' -exec cp "{}" "${FONTS_DIR}" \;
	)
	sudo fc-cache -f
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
