#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

NVM_DIR="${HOME}/.nvm"
NVIM_VERSION="${NVIM_VERSION:=0.7.2}"

do_install() {
	info "[neovim] Install"
	local nvim="/tmp/nvim.deb"
	sudo rm -rf "${nvim}"
	download "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux64.deb" "${nvim}"
	sudo dpkg -i --force-overwrite "${nvim}"
}

do_configure() {
	info "[neovim] Configure"
	info "[neovim][configure] Set as default editor"
	local nvim_path
	nvim_path="$(type -P nvim)"
	sudo update-alternatives --install /usr/bin/vi vi "$nvim_path" 60
	sudo update-alternatives --set vi "$nvim_path"
	sudo update-alternatives --install /usr/bin/vim vim "$nvim_path" 60
	sudo update-alternatives --set vim "$nvim_path"
	sudo update-alternatives --install /usr/bin/editor editor "$nvim_path" 60
	sudo update-alternatives --set editor "$nvim_path"

	info "[neovim][configure] Create configuration directory symlink"
	rm -rf "${XDG_CONFIG_HOME}/nvim" && mkdir -p "${XDG_CONFIG_HOME}"
	ln -fs "$(pwd)/nvim" "${XDG_CONFIG_HOME}/nvim"

	info "[neovim][configure] Install the neovim package for languages"
	info "[neovim][configure][languages] Python"
	python3 -m pip install --quiet neovim neovim-remote --user

	info "[neovim][configure][languages] Node.js"
	# shellcheck source=../../.nvm/nvm.sh
	source "${NVM_DIR}/nvm.sh" && npm install --quiet -g neovim

	info "[neovim][configure] Install dependencies for LSP"
	info "[neovim][configure][dependencies] yarn"
	# shellcheck source=../../.nvm/nvm.sh
	source "${NVM_DIR}/nvm.sh"
	npm install --quiet -g yarn

	info "[neovim][configure] Install linters for LSP"
	do_update_linters
}

do_update_linters() {
	info "[neovim][configure][linters] markdownlint-cli"
	# shellcheck source=../../.nvm/nvm.sh
	source "${NVM_DIR}/nvm.sh"
	npm install --quiet -g markdownlint-cli

	info "[neovim][configure][linters] hadolint"
	asset=$(curl --silent "https://api.github.com/repos/hadolint/hadolint/releases/latest" | jq -r '.assets // [] | .[] | select(.name | startswith("hadolint-Linux-x86_64")) | .url')
	if [[ -z $asset ]]; then
		warn "Cannot find a release. Please try again later."
	else
		local hadolint="${HOME}/bin/hadolint"
		download "${asset}" "${hadolint}"
		chmod +x "${hadolint}"
	fi

	info "[neovim][configure][linters] jsonlint"
	npm install jsonlint -g

	info "[neovim][configure][linters] stylua"
	asset=$(curl --silent "https://api.github.com/repos/JohnnyMorganz/StyLua/releases/latest" | jq -r '.assets // [] | .[] | select(.name | contains("linux")) | .url')
	if [[ -z $asset ]]; then
		warn "Cannot find a release. Please try again later."
	else
		local stylua="${HOME}/bin/stylua"
		download "${asset}" "" | gunzip -c >"${stylua}"
		chmod +x "${stylua}"
	fi

	info "[neovim][configure][linters] shfmt"
	/usr/local/go/bin/go install mvdan.cc/sh/v3/cmd/shfmt@latest

	info "[neovim][configure][linters] golangci-lint"
	/usr/local/go/bin/go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	ln -fs "$(pwd)/golangci-lint/golangci.yml" "${HOME}/.golangci.yml"
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
	"update_linters")
		shift
		do_update_linters "$@"
		;;
	*)
		error "$(basename "$0"): '$command' is not a valid command"
		;;
	esac
}

main "$@"
