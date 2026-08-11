# syntax=docker/dockerfile:1

# Python base images. Four build targets, built and tagged by the repository Makefile.
#
#   builder      Poetry and the C toolchain for the builder stage of an application image.
#   runtime      Hardened production interpreter. No compiler, no Poetry, no installer, non-root.
#   development  Runtime plus Poetry, debugpy, bash, and git.
#   cli          Local tooling image invoked from a project Makefile, never inherited by a Dockerfile.

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

# The project-local virtual environment is on PATH, so a stage that ran `poetry install` reaches its
# dependencies with no activation step and the runtime target resolves the very same path.
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

# The C toolchain stays. This is the stage an application compiles its wheels in, so deleting it
# here would only push the same install into the consuming Dockerfile.
RUN apk add --no-cache ca-certificates git build-base libffi-dev openssl-dev linux-headers \
    && python3 -m pip install --no-cache-dir "pip==${PIP_VERSION}" "poetry==${POETRY_VERSION}" \
    && rm -rf /root/.cache

# Drops to app, the uid the runtime runs as, so the virtual environment a build stage produces
# already carries the runtime's ownership.
RUN addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app \
    && git config --system --add safe.directory /app

WORKDIR /app

USER app

FROM builder AS cli

LABEL org.opencontainers.image.title="gustavofreze/python-cli" \
      org.opencontainers.image.description="Python 3.14 CLI tooling image: Poetry, git, bash, docker CLI"

# Root on purpose: this image is invoked over a bind mount owned by the caller and must write into
# it. One-shot, no exposed port, audited with the CIS-DI-0001 exemption. DL3002 is the lint side of
# that exception, ignored here so it stays active on every target that must end non-root.
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

# pip is uninstalled on purpose. It is the largest dependency tree in the image (CacheControl,
# requests, urllib3, msgpack, a vendored setuptools) and nothing in it is reachable from an
# application running a virtual environment the builder already populated. The ensurepip wheel stays:
# it sits outside sys.path, and it keeps `python3 -m ensurepip` available as the way back.
RUN apk add --no-cache ca-certificates \
    && python3 -m pip uninstall --yes pip \
    && rm -rf /root/.cache \
    && addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app

WORKDIR /app

USER app

# No HEALTHCHECK: this is a language base, not a service. It starts no process of its own, so there
# is no liveness contract to probe. The application that inherits it declares its own.
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

# The runtime removed pip, so this target restores it from ensurepip and pins it forward first.
# debugpy has no musl wheel for every architecture, so the compiler enters under a virtual group and
# leaves in the same layer.
RUN apk add --no-cache bash git \
    && apk add --no-cache --virtual .build-deps build-base \
    && python3 -m ensurepip \
    && python3 -m pip install --no-cache-dir --upgrade "pip==${PIP_VERSION}" \
    && python3 -m pip install --no-cache-dir "poetry==${POETRY_VERSION}" "debugpy==${DEBUGPY_VERSION}" \
    && apk del .build-deps \
    && rm -rf /root/.cache \
    && git config --system --add safe.directory /app

USER app
