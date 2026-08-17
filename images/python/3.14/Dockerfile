# syntax=docker/dockerfile:1

FROM python:3.14.7-alpine3.24 AS builder

LABEL org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.title="gustavofreze/python-builder" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.description="Python 3.14 Poetry and C build toolchain for application builder stages" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/python/README.md"

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

RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    --mount=type=bind,source=constraints.txt,target=/tmp/constraints.txt \
    apk add --no-cache ca-certificates git build-base libffi-dev openssl-dev linux-headers \
    && python3 -m pip install --no-cache-dir \
        --requirement /tmp/requirements.txt --constraint /tmp/constraints.txt \
    && rm -rf /root/.cache

RUN addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app \
    && git config --system --add safe.directory /app

WORKDIR /app

USER 1000

FROM builder AS cli

LABEL org.opencontainers.image.title="gustavofreze/python-cli" \
      org.opencontainers.image.description="Python 3.14 CLI tooling image: Poetry, git, bash, curl"

# hadolint ignore=DL3002
USER 0

RUN apk add --no-cache bash curl

FROM python:3.14.7-alpine3.24 AS runtime

LABEL org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.title="gustavofreze/python" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.description="Hardened non-root Python 3.14 production runtime" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/python/README.md"

ENV PATH="/app/.venv/bin:${PATH}" \
    VIRTUAL_ENV=/app/.venv \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONFAULTHANDLER=1

RUN apk add --no-cache ca-certificates \
    && python3 -m pip uninstall --yes pip \
    && rm -rf /root/.cache \
    && addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app

WORKDIR /app

USER 1000

CMD ["python3"]

FROM runtime AS development

LABEL org.opencontainers.image.title="gustavofreze/python-development" \
      org.opencontainers.image.description="Python 3.14 development runtime: runtime plus Poetry, debugpy, bash, and git"

ENV PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_CACHE_DIR=/tmp/poetry-cache \
    POETRY_VIRTUALENVS_IN_PROJECT=true

USER 0

RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    --mount=type=bind,source=requirements-development.txt,target=/tmp/requirements-development.txt \
    --mount=type=bind,source=constraints.txt,target=/tmp/constraints.txt \
    apk add --no-cache bash git \
    && apk add --no-cache --virtual .build-deps build-base \
    && python3 -m ensurepip \
    && python3 -m pip install --no-cache-dir --upgrade \
        --requirement /tmp/requirements-development.txt --constraint /tmp/constraints.txt \
    && apk del .build-deps \
    && rm -rf /root/.cache \
    && git config --system --add safe.directory /app

USER 1000
