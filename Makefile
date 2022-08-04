include test.mk

.DEFAULT_GOAL := all
.PHONY: git

all: system git terminal devops ## Install and configure everything (default)
help: ## Display help
	@grep -hE '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

system: system-install system-configure ## Install and configure
system-install: ## Install system packages
	@./scripts/system.sh install
system-configure: ## Create directories, install fonts, etc.
	@./scripts/system.sh configure

git: ## Configure git
	@./scripts/git.sh configure

terminal: zsh ohmyzsh bat fzf delta ## Setup the terminal
zsh: ## Configure zsh
	@./scripts/zsh.sh configure
ohmyzsh: ohmyzsh-install ohmyzsh-configure ## Install and configure Oh My Zsh
ohmyzsh-install: ## Install Oh My Zsh
	@./scripts/ohmyzsh.sh install
ohmyzsh-configure: ## Configure Oh My Zsh
	@./scripts/ohmyzsh.sh configure
bat: bat-install bat-configure ## Install and configure bat
bat-install: ## Install bat
	@./scripts/bat.sh install
bat-configure: ## Configure bat
	@./scripts/bat.sh configure
fzf: ## Install FZF
	@./scripts/fzf.sh install
delta: delta-install delta-configure ## Install and configure delta
delta-install: ## Install delta
	@./scripts/delta.sh install
delta-configure: ## Configure delta
	@./scripts/delta.sh configure

devops: awscli ctop tfsec #kubectl istioctl ## Install and configure devops tools
awscli: ## Install awscli
	@./scripts/awscli.sh install
ctop: ctop-install ctop-configure ## Install and configure ctop
ctop-install: ## Install ctop
	@./scripts/ctop.sh install
ctop-configure: ## Configure ctop
	@./scripts/ctop.sh configure
tfsec: ## Install tfsec
	@./scripts/tfsec.sh install