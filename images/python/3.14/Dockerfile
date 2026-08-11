# syntax=docker/dockerfile:1

# Python base images. One Dockerfile, four build targets, built and tagged by the repository
# Makefile. Consumers pull the published tags and never build from this file.
#
#   builder      Poetry and the C toolchain for the builder stage of an application image.
#   runtime      Hardened production interpreter. No compiler, no Poetry, non-root.
#   development  Runtime plus Poetry, debugpy, bash, and git.
#   cli          Local tooling image (Poetry, git, bash, docker CLI) invoked from a project
#                Makefile, never inherited by a Dockerfile.

FROM python:3.14.6-alpine3.24 AS builder

LABEL org.opencontainers.image.title="gustavofreze/python-builder" \
      org.opencontainers.image.description="Python 3.14 Poetry and C build toolchain for application builder stages" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/python/README.md"

ARG PIP_VERSION=26.2
ARG POETRY_VERSION=2.4.1

# Byte code is never written to a bind mount or a read-only layer, output is unbuffered so a crash
# loses no log line, and pip is quiet and cacheless. The project-local virtual environment is on
# PATH, so a stage that runs `poetry install` reaches its own dependencies with no activation step
# and the runtime target below resolves the very same path.
ENV PATH="/app/.venv/bin:${PATH}" \
    VIRTUAL_ENV=/app/.venv \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_CACHE_DIR=/tmp/poetry-cache \
    POETRY_VIRTUALENVS_IN_PROJECT=true

# The builder is the stage an application compiles its wheels in, so the C toolchain stays: deleting
# it here would only push the same install into the consuming Dockerfile. ca-certificates backs the
# TLS fetches Poetry makes and git resolves git-hosted dependencies.
RUN apk add --no-cache ca-certificates git build-base libffi-dev openssl-dev linux-headers \
    && python3 -m pip install --no-cache-dir "pip==${PIP_VERSION}" "poetry==${POETRY_VERSION}" \
    && rm -rf /root/.cache

# The builder installs packages as root above, then drops to app (uid 1000, the same user the
# runtime runs as) as its last USER, so the virtual environment the build stage produces already
# carries the runtime's ownership. The cli variant below re-elevates for its own installs.
# safe.directory is set system-wide and scoped to the working directory, so git trusts a
# bind-mounted checkout owned by another uid without disabling the ownership check everywhere.
RUN addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app \
    && git config --system --add safe.directory /app

WORKDIR /app

USER app

FROM builder AS cli

LABEL org.opencontainers.image.title="gustavofreze/python-cli" \
      org.opencontainers.image.description="Python 3.14 CLI tooling image: Poetry, git, bash, docker CLI"

# cli inherits the non-root builder but is the local tooling image a project Makefile invokes over a
# bind mount, so it must write into a host directory owned by the caller. It re-elevates to root to
# install that tooling and stays root as the documented CLI exception: a one-shot tooling image with
# no long-running process, audited with the CIS-DI-0001 exemption. DL3002 (last USER should not be
# root) is the lint side of that same exception, ignored on this one line so it stays active on every
# service target that must end non-root.
# hadolint ignore=DL3002
USER root

RUN apk add --no-cache bash curl docker-cli

FROM python:3.14.6-alpine3.24 AS runtime

LABEL org.opencontainers.image.title="gustavofreze/python" \
      org.opencontainers.image.description="Hardened non-root Python 3.14 production runtime" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/python/README.md"

ENV PATH="/app/.venv/bin:${PATH}" \
    VIRTUAL_ENV=/app/.venv \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONFAULTHANDLER=1

# No compiler, no Poetry, and no installer reach production. The builder stage resolves and compiles
# the dependencies, this stage only runs them.
#
# pip is uninstalled on purpose. It is the largest dependency tree in the image (CacheControl,
# requests, urllib3, msgpack, a vendored setuptools) and none of it is reachable from an application
# that runs a virtual environment the builder already populated, so removing it drops that whole
# surface from the production image. The `ensurepip` wheel the interpreter ships is left in place: it
# sits outside sys.path and is never imported, so it adds no attack surface, and it keeps
# `python3 -m ensurepip` working for the rare consumer that needs the installer back.
RUN apk add --no-cache ca-certificates \
    && python3 -m pip uninstall --yes pip \
    && rm -rf /root/.cache \
    && addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app

WORKDIR /app

USER app

# No HEALTHCHECK here on purpose. This target is a language base, not a service: it starts no
# long-running process of its own, so there is no liveness contract to probe. The application that
# inherits it declares the health check for the process it actually runs.
CMD ["python3"]

FROM runtime AS development

LABEL org.opencontainers.image.title="gustavofreze/python-development" \
      org.opencontainers.image.description="Python 3.14 development runtime: runtime plus Poetry, debugpy, bash, and git"

ARG PIP_VERSION=26.2
ARG POETRY_VERSION=2.4.1
ARG DEBUGPY_VERSION=1.8.21

ENV PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_CACHE_DIR=/tmp/poetry-cache \
    POETRY_VIRTUALENVS_IN_PROJECT=true

USER root

# The runtime removed pip, so this target restores it from the interpreter's own ensurepip wheel and
# pins it forward before installing anything. debugpy has no musl wheel for every architecture, so
# the compiler enters under a virtual group and leaves in the same layer, keeping the development
# image free of a build toolchain.
RUN apk add --no-cache bash git \
    && apk add --no-cache --virtual .build-deps build-base \
    && python3 -m ensurepip \
    && python3 -m pip install --no-cache-dir --upgrade "pip==${PIP_VERSION}" \
    && python3 -m pip install --no-cache-dir "poetry==${POETRY_VERSION}" "debugpy==${DEBUGPY_VERSION}" \
    && apk del .build-deps \
    && rm -rf /root/.cache \
    && git config --system --add safe.directory /app

USER app
