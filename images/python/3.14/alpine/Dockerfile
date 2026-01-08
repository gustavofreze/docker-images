FROM python:3.14-alpine

LABEL author="Gustavo Freze" \
      maintainer="Gustavo Freze" \
      org.label-schema.name="gustavofreze/python:3.14" \
      org.label-schema.usage="https://github.com/gustavofreze/docker-images/blob/main/images/python/README.md" \
      org.label-schema.vcs-url="https://github.com/gustavofreze/docker-images/blob/main/images/python/3.14/alpine/Dockerfile" \
      org.label-schema.schema-version="1.0"

ARG PYTHONPATH=""
ARG POETRY_VERSION=2.2

ENV PIP_NO_CACHE_DIR=1
ENV PIP_ROOT_USER_ACTION=ignore
ENV POETRY_NO_INTERACTION=1
ENV POETRY_VIRTUALENVS_IN_PROJECT=true

RUN python -m pip install --no-cache-dir --upgrade pip "poetry==${POETRY_VERSION}" \
    && rm -rf /root/.cache/pip
