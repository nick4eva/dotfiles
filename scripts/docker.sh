#!/usr/bin/env bash

set -e

# shellcheck source=../scripts/util.sh
source "$(pwd)/scripts/util.sh"

do_install() {
	if is_installed docker; then
		info "[docker] Already installed"
		return
	fi

	info "[docker] Install Docker CE from the official apt repo"
	sudo apt-get update
	# sudo drops DEBIAN_FRONTEND; without it a tzdata dependency stops at a time zone prompt
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt-get update
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	sudo usermod -aG docker "${USER}"
	warn "[docker][install] Log out and back in for docker group membership to apply"
}

do_configure() {
	info "[docker] Configure"

	info "[docker][configure] Install daemon.json (address pools outside VPN 172.16/12 and Tailscale 100.64/10)"
	sudo install -D -m 644 "$(pwd)/docker/daemon.json" /etc/docker/daemon.json

	info "[docker][configure] Install daily cleanup script and systemd timer"
	sudo install -m 755 "$(pwd)/docker/docker-cleanup.sh" /usr/local/sbin/docker-cleanup.sh
	sudo install -m 644 "$(pwd)/docker/docker-cleanup.service" "$(pwd)/docker/docker-cleanup.timer" /etc/systemd/system/
	# Containers (such as the CI test image) run without systemd
	if [[ -d /run/systemd/system ]]; then
		sudo systemctl daemon-reload
		sudo systemctl enable --now docker-cleanup.timer
	else
		warn "[docker][configure] systemd is not running; enable the timer later: sudo systemctl enable --now docker-cleanup.timer"
	fi

	warn "[docker][configure] If daemon.json changed, restart manually: sudo systemctl restart docker"
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
