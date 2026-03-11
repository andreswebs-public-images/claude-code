# syntax=docker/dockerfile:1
FROM docker.io/node:25-trixie

ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

COPY --from=mikefarah/yq /usr/bin/yq /usr/local/bin/
COPY --from=denoland/deno:bin /deno /usr/local/bin/
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bunx /usr/local/bin/
COPY --from=golang:1.26-alpine /usr/local/go/ /usr/local/go/

RUN <<EOT
    set -o errexit
    apt-get update
    apt-get install --yes --no-install-recommends \
        bash-completion \
        bc \
        bzip2 \
        ca-certificates \
        curl \
        direnv \
        dnsutils \
        file \
        gh \
        git \
        gnupg \
        htop \
        jq \
        less \
        lsof \
        man-db \
        netcat-openbsd \
        openssh-client \
        procps \
        psmisc \
        ripgrep \
        rsync \
        shellcheck \
        shelltestrunner \
        socat \
        sudo \
        tree \
        tmux \
        unzip \
        vim \
        zip
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOT

ARG APP_UID="2000"
ARG APP_GID="2000"
ARG APP_USER="claude"

RUN \
    groupadd \
      --gid "${APP_GID}" "${APP_USER}" && \
    useradd \
      --gid "${APP_GID}" \
      --uid "${APP_UID}" \
      --comment "" \
      --shell /bin/bash \
      --create-home \
      "${APP_USER}"

RUN \
    mkdir --parents /etc/sudoers.d/ && \
    echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${APP_USER}" && \
    chmod 0440 "/etc/sudoers.d/${APP_USER}"

RUN mkdir /claude
RUN chown --recursive "${APP_USER}:${APP_USER}" /claude

WORKDIR /workspace
RUN chown --recursive "${APP_USER}:${APP_USER}" /workspace

USER "${APP_USER}"

ENV HOME="/home/${APP_USER}"
ENV NPM_CONFIG_PREFIX="${HOME}/.npm-global"
ENV PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${HOME}/.bun/bin:/usr/local/go/bin:${HOME}/go/bin:${PATH}"
ENV EDITOR="vim"
ENV DO_NOT_TRACK="true"
ENV CLAUDE_CONFIG_DIR="/claude"

RUN mkdir --parents "${HOME}/.local/share"
RUN mkdir --parents "${HOME}/.local/bin"
RUN echo 'export PS1="\e[34m\u@\h\e[35m \w\e[0m\n$ "' >> "${HOME}/.bashrc"

RUN npm install --global @dbml/cli
RUN npm install --global @sourcemeta/jsonschema
RUN npm install --global agent-browser
RUN go install mvdan.cc/sh/v3/cmd/shfmt@latest

RUN <<EOT
    set -o errexit -o pipefail
    git clone https://github.com/wedow/ticket.git "${HOME}/.local/share/ticket"
    cd "${HOME}/.local/share/ticket" || exit 1
    ln --symbolic "$(pwd)/ticket" "${HOME}/.local/bin/tk"
EOT

RUN <<EOT
    {
        echo ":set number"
        echo ":set et"
        echo ":set sw=2 ts=2 sts=2"
    } > "${HOME}/.vimrc"
EOT

RUN <<EOT
    set -o errexit -o pipefail
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        "https://claude.ai/install.sh" | \
    bash
EOT

ENTRYPOINT ["claude"]
