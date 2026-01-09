FROM python:3.14-alpine

LABEL org.opencontainers.image.url="https://github.com/gustavofreze/docker-images"
LABEL org.opencontainers.image.title="gustavofreze/python:3.14-alpine"
LABEL org.opencontainers.image.source="https://github.com/gustavofreze/docker-images"
LABEL org.opencontainers.image.authors="Gustavo Freze"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.description="Python 3.14 Alpine image for development"
LABEL org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/python/README.md"

ARG PYTHONPATH=""
ARG POETRY_VERSION=2.2

ENV PIP_NO_CACHE_DIR=1
ENV PIP_ROOT_USER_ACTION=ignore
ENV POETRY_NO_INTERACTION=1
ENV POETRY_VIRTUALENVS_IN_PROJECT=true

RUN python -m pip install --no-cache-dir --upgrade pip==24.3.1 "poetry==${POETRY_VERSION}" \
    && rm -rf /root/.cache/pip
