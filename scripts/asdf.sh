#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

ASDF_VERSION="${ASDF_VERSION:=0.11.2}"

do_install() {
	if [[ "$(asdf --version 2>/dev/null)" == *"${ASDF_VERSION}"* ]]; then
		info "[asdf] ${ASDF_VERSION} already installed"
		return
	fi

	info "[asdf] Install ${ASDF_VERSION}"
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v"${ASDF_VERSION}"
}

do_configure() {
	info "[asdf] Configure"
	source "${HOME}/.asdf/asdf.sh"
	info "[asdf][configure] Create config file symlink"
	ln -fs "$(pwd)/asdf/tool-versions" "${HOME}/.tool-versions"
	info "[asdf][configure] Add plugins"
	asdf plugin add deno
	asdf plugin add github-cli
	asdf plugin add act
	asdf plugin add bat
	asdf plugin add delta
	asdf plugin add dotnet
	asdf plugin add nodejs
	asdf plugin add tflint
	asdf plugin add powershell-core
	asdf plugin add broot https://github.com/cmur2/asdf-broot.git
	asdf plugin add poetry https://github.com/asdf-community/asdf-poetry.git
	asdf plugin add k9s https://github.com/looztra/asdf-k9s
	asdf plugin add glow https://github.com/grimoh/asdf-glow.git
	asdf plugin add stylua
	asdf plugin add lazygit
	asdf plugin add lazydocker https://github.com/comdotlinux/asdf-lazydocker.git
	asdf plugin add editorconfig-checker
	asdf plugin add actionlint
	asdf plugin add hadolint
	asdf plugin add dust
	asdf plugin add exa
	info "[asdf][configure] Installing tools"
	asdf install
	# info "[asdf][configure] Plugins post-install configuration"
	# info "[asdf][configure][github-cli] Install gh cli extensions"
	#  gh extension install kavinvalli/gh-repo-fzf
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
