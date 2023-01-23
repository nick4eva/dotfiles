include test.mk

.DEFAULT_GOAL := all
.PHONY: git

all: system git asdf terminal devops neovim ## Install and configure everything (default)
help: ## Display help
	@grep -hE '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

system: system-install system-configure ## Install and configure
system-install: ## Install system packages
	@./scripts/system.sh install
system-configure: ## Create directories, install fonts, etc.
	@./scripts/system.sh configure

git: ## Configure git
	@./scripts/git.sh configure

terminal: zsh ohmyzsh bat-configure lsd fzf delta-configure ripgrep shellcheck lazygit win32yank navi ## Setup the terminal
zsh: ## Configure zsh
	@./scripts/zsh.sh configure
ohmyzsh: ohmyzsh-install ohmyzsh-configure ## Install and configure Oh My Zsh
ohmyzsh-install: ## Install Oh My Zsh
	@./scripts/ohmyzsh.sh install
ohmyzsh-configure: ## Configure Oh My Zsh
	@./scripts/ohmyzsh.sh configure
bat-configure: ## Configure bat
	@./scripts/bat.sh configure
lsd: ## Install lsd
	@./scripts/lsd.sh install
fzf: ## Install FZF
	@./scripts/fzf.sh install
delta-configure: ## Configure delta
	@./scripts/delta.sh configure
ripgrep: ## Install ripgrep
	@./scripts/ripgrep.sh install
shellcheck: ## Install shellcheck
	@./scripts/shellcheck.sh install
lazygit: ## Configure lazygit
	@./scripts/lazygit.sh configure
win32yank: ## Install win32yank
	@./scripts/win32yank.sh install
navi: ## Install navi
	@./scripts/navi.sh install

devops: awscli ctop tfsec ansible #kubectl istioctl ## Install and configure devops tools
awscli: ## Install awscli
	@./scripts/awscli.sh install
ctop: ctop-install ctop-configure ## Install and configure ctop
ctop-install: ## Install ctop
	@./scripts/ctop.sh install
ctop-configure: ## Configure ctop
	@./scripts/ctop.sh configure
tfsec: ## Install tfsec
	@./scripts/tfsec.sh install
ansible: ansible-core ansible-lint ## Install Ansible
ansible-core: ## Install Ansible Core
	@./scripts/ansible.sh install
ansible-lint: ## Install Ansible Lint
	@./scripts/ansible-lint.sh install

neovim: tree-sitter neovim-install #neovim-configure ## Install and configure neovim and tree-sitter
tree-sitter: ## Install tree-sitter
	@./scripts/tree-sitter.sh install
neovim-install: ## Install neovim
	@./scripts/neovim.sh install
# neovim-configure: ## Configure neovim
# 	@./scripts/neovim.sh configure

asdf: asdf-install asdf-configure ## Install and configure asdf
asdf-install:
	@./scripts/asdf.sh install
asdf-configure:
	@./scripts/asdf.sh configure
