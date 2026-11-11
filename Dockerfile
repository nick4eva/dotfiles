FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive

# Fail instead of waiting for a username when a cloned repo is gone (e.g. a removed asdf plugin)
ENV GIT_TERMINAL_PROMPT=0

# Workaround: archive.ubuntu.com and security.ubuntu.com stopped resolving on GitHub runners (2026-11-11),
# so take packages from a mirror outside the ubuntu.com zone
RUN sed -i -E 's#http://(archive|security)\.ubuntu\.com/ubuntu/?#http://mirrors.edge.kernel.org/ubuntu/#' /etc/apt/sources.list

RUN apt-get update\
    && apt-get --no-install-recommends -y install \
    sudo \
    build-essential \
    software-properties-common \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN echo "Set disable_coredump false" >> /etc/sudo.conf

RUN adduser --disabled-password --gecos '' test && adduser test sudo && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER test

COPY --chown=test:test . /home/test/dotfiles

ENV USER=test

ENV PATH="/home/test/bin:${PATH}"

WORKDIR /home/test/dotfiles
