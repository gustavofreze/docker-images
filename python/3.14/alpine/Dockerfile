FROM python:3.14-alpine

LABEL author="Gustavo Freze" \
      maintainer="Gustavo Freze" \
      org.label-schema.name="gustavofreze/python:3.14" \
      org.label-schema.usage="https://github.com/gustavofreze/docker-images/blob/main/python/README.md" \
      org.label-schema.vcs-url="https://github.com/gustavofreze/docker-images/blob/main/python:3.14/alpine/Dockerfile" \
      org.label-schema.schema-version="1.0"

ARG POETRY_VERSION=1.8.4

ENV PIP_ROOT_USER_ACTION=ignore
ENV POETRY_NO_INTERACTION=1
ENV POETRY_VIRTUALENVS_IN_PROJECT=true

RUN apk add --no-cache build-base git \
    && python -m pip install --upgrade pip \
    && python -m pip install "poetry==${POETRY_VERSION}"
