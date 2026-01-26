# syntax=docker/dockerfile:1
FROM docker.io/debian:trixie

ARG DEBIAN_FRONTEND="noninteractive"

RUN <<EOT
    set -o errexit && \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        bc \
        bzip2 \
        ca-certificates \
        curl \
        dnsutils \
        gh \
        git \
        jq \
        less \
        lsof \
        man-db \
        procps \
        psmisc \
        ripgrep \
        rsync \
        socat \
        tree \
        unzip \
        vim \
        zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
EOT

COPY --from=mikefarah/yq /usr/bin/yq /usr/local/bin/
COPY --from=denoland/deno:bin-2.6.4 /deno /usr/local/bin/
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bunx /usr/local/bin/

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

RUN mkdir /claude
RUN chown --recursive "${APP_USER}:${APP_USER}" /claude

WORKDIR /workspace
RUN chown --recursive "${APP_USER}:${APP_USER}" /workspace

USER "${APP_USER}"

ENV HOME="/home/${APP_USER}"
ENV PATH="${HOME}/.local/bin:${HOME}/.bun/bin:${PATH}"
ENV EDITOR="vim"
ENV DO_NOT_TRACK="true"
ENV CLAUDE_CONFIG_DIR="/claude"

RUN echo 'export PS1="\e[34m\u@\h\e[35m \w\e[0m\n$ "' >> "${HOME}/.bashrc"

RUN <<EOT
    set -o errexit -o pipefail && \
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        "https://claude.ai/install.sh" | \
    bash
EOT

RUN <<EOT
    set -o errexit -o pipefail && \
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        "https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh" | \
    bash
EOT

RUN bun install --global @dbml/cli
RUN bun install --global @sourcemeta/jsonschema

RUN ln --symbolic $(which bun) "${HOME}/.local/bin/node"

ENTRYPOINT ["claude"]
