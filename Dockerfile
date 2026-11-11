FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive

# Fail instead of waiting for a username when a cloned repo is gone (e.g. a removed asdf plugin)
ENV GIT_TERMINAL_PROMPT=0

# Single apt hosts keep failing from GitHub runners (archive.ubuntu.com DNS, then mirrors.edge.kernel.org
# timeouts, 2026-11-11), so list several mirrors: apt moves to the next one when a mirror fails
RUN printf '%s\n' \
    http://archive.ubuntu.com/ubuntu/ \
    http://mirrors.edge.kernel.org/ubuntu/ \
    http://mirrors.mit.edu/ubuntu/ \
    > /etc/apt/ubuntu-mirrors.txt \
    && sed -i -E 's#http://(archive|security)\.ubuntu\.com/ubuntu/?#mirror+file:/etc/apt/ubuntu-mirrors.txt#' /etc/apt/sources.list \
    && echo 'Acquire::http::Timeout "10";' > /etc/apt/apt.conf.d/99timeout

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
