# syntax=docker/dockerfile:1

# PHP base images. One Dockerfile, four build targets, built and tagged by the repository
# Makefile. Consumers pull the published tags and never build from this file.
#
#   builder      Composer build toolchain for the builder stage of an application image.
#   runtime      Hardened production PHP-FPM runtime. No build tools, no dev tooling, non-root.
#   development  Runtime plus Xdebug, Composer, bash, git, and development OPcache settings.
#   cli          Local tooling image (Composer, Xdebug coverage, CodeSniffer, Mess Detector,
#                docker CLI) invoked from a project Makefile, never inherited by a Dockerfile.

FROM php:8.5.9-cli-alpine3.24 AS builder

LABEL org.opencontainers.image.title="gustavofreze/php-builder" \
      org.opencontainers.image.description="PHP 8.5 Composer build toolchain for application builder stages" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/php/README.md"

# ca-certificates backs every TLS fetch Composer makes, git and unzip resolve git-hosted and
# dist-hosted packages, and libzip backs the zip extension below. The compiler toolchain enters
# under a virtual group and leaves in the same layer, so nothing it fetched survives into the image.
RUN apk add --no-cache ca-certificates git unzip libzip \
    && apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS} linux-headers libzip-dev \
    && docker-php-ext-install -j"$(nproc)" bcmath pdo_mysql zip \
    && apk del .build-deps \
    && mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"

COPY --from=composer:2.9.8 /usr/bin/composer /usr/local/bin/composer

# COMPOSER_ALLOW_SUPERUSER silences the root warning for the cli variant below, which stays root.
# COMPOSER_HOME is a www-data-owned path so Composer can write its cache and config once the
# builder drops privileges.
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer

WORKDIR /var/www/html

# The builder installs packages as root above, then drops to www-data (uid 82, the same user the
# runtime runs as) as its last USER. A builder needs root only to install packages at build time,
# not when an application inherits it, so the build stage runs Composer non-root and the vendor tree
# it produces already carries the runtime's ownership. The cli variant below re-elevates for its own
# installs. safe.directory is set system-wide and scoped to the working directory, so git trusts a
# bind-mounted checkout owned by another uid without disabling the ownership check everywhere.
RUN install -d -o www-data -g www-data /composer \
    && chown www-data:www-data /var/www/html \
    && git config --system --add safe.directory /var/www/html

USER www-data

FROM builder AS cli

LABEL org.opencontainers.image.title="gustavofreze/php-cli" \
      org.opencontainers.image.description="PHP 8.5 CLI tooling image: Composer, Xdebug coverage, CodeSniffer, Mess Detector, docker CLI"

# Every tool is pinned to an exact release. Xdebug comes through PECL, which verifies the package it
# downloads. The three phars are fetched over plain HTTPS, so they carry their published sha256 here:
# a swapped or tampered release fails the build instead of shipping.
ARG PHPMD_VERSION=2.15.0
ARG PHPCS_VERSION=4.0.1
ARG XDEBUG_VERSION=3.5.3
ARG PHPMD_SHA256=6a28ef55de0c753b070d1d1580bb08a0d146016f89f0eddcef60ac4fc1083544
ARG PHPCS_SHA256=a211817baf28918b2cff8e80af5d53d7e7060f9761384c0d9df0f003afb51a40
ARG PHPCBF_SHA256=2b6c98c48eafc2e211cec397a0e9693010b09791760b93eef2606b38df5351af

# cli inherits the non-root builder but is the local tooling image a project Makefile invokes over a
# bind mount, so it must write into a host directory owned by the caller. It re-elevates to root to
# install that tooling and stays root as the documented CLI exception: a one-shot tooling image with
# no long-running process, audited with the CIS-DI-0001 exemption. DL3002 (last USER should not be
# root) is the lint side of that same exception, ignored on this one line so it stays active on every
# service target that must end non-root.
# hadolint ignore=DL3002
USER root

RUN apk add --no-cache bash curl docker-cli \
    && apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS} linux-headers \
    && pecl install "xdebug-${XDEBUG_VERSION}" \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps \
    && rm -rf /tmp/pear

# Each phar is fetched to a scratch path and only reaches PATH after its checksum matches, so an
# unverified artifact is never executable inside the image, not even between two instructions.
RUN curl -fsSL -o /tmp/phpcs.phar "https://github.com/PHPCSStandards/PHP_CodeSniffer/releases/download/${PHPCS_VERSION}/phpcs.phar" \
    && curl -fsSL -o /tmp/phpcbf.phar "https://github.com/PHPCSStandards/PHP_CodeSniffer/releases/download/${PHPCS_VERSION}/phpcbf.phar" \
    && curl -fsSL -o /tmp/phpmd.phar "https://github.com/phpmd/phpmd/releases/download/${PHPMD_VERSION}/phpmd.phar" \
    && printf '%s  /tmp/phpcs.phar\n%s  /tmp/phpcbf.phar\n%s  /tmp/phpmd.phar\n' \
        "${PHPCS_SHA256}" "${PHPCBF_SHA256}" "${PHPMD_SHA256}" > /tmp/tools.sha256 \
    && sha256sum -c /tmp/tools.sha256 \
    && install -m 0755 /tmp/phpcs.phar /usr/local/bin/phpcs \
    && install -m 0755 /tmp/phpcbf.phar /usr/local/bin/phpcbf \
    && install -m 0644 /tmp/phpmd.phar /usr/local/lib/phpmd.phar \
    && rm -f /tmp/phpcs.phar /tmp/phpcbf.phar /tmp/phpmd.phar /tmp/tools.sha256

# The Mess Detector phar sits off PATH and is reached through this wrapper, which silences the
# deprecation notices its own 2023 code base raises on PHP 8.5. The name on PATH is the one a caller
# types, so the indirection is invisible.
COPY --chmod=755 bin/phpmd /usr/local/bin/phpmd

COPY conf/xdebug.ini ${PHP_INI_DIR}/conf.d/zz-gustavofreze-30-xdebug.ini
COPY conf/cli.ini ${PHP_INI_DIR}/conf.d/zz-gustavofreze-90-cli.ini

FROM php:8.5.9-fpm-alpine3.24 AS runtime

LABEL org.opencontainers.image.title="gustavofreze/php" \
      org.opencontainers.image.description="Hardened non-root PHP 8.5 FPM production runtime" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/php/README.md"

# php.ini-production becomes the active php.ini and the development template is deleted, so the
# hardened defaults cannot be reactivated by an accidental rename inside a consuming image.
RUN apk add --no-cache ca-certificates libzip \
    && apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS} linux-headers libzip-dev \
    && docker-php-ext-install -j"$(nproc)" bcmath pdo_mysql zip \
    && apk del .build-deps \
    && mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini" \
    && rm -f "${PHP_INI_DIR}/php.ini-development"

# Drop-ins are namespaced and numbered. PHP loads conf.d alphabetically, so the number fixes the
# order the derived targets rely on: hardening (10) lands before the development override (90).
COPY conf/hardening.ini ${PHP_INI_DIR}/conf.d/zz-gustavofreze-10-hardening.ini
COPY conf/opcache.prod.ini ${PHP_INI_DIR}/conf.d/zz-gustavofreze-20-opcache.ini
COPY conf/fpm-shutdown.conf /usr/local/etc/php-fpm.d/zz-gustavofreze-shutdown.conf
COPY --chmod=755 bin/php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck

WORKDIR /var/www/html

RUN chown www-data:www-data /var/www/html

USER www-data

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD ["php-fpm-healthcheck"]

CMD ["php-fpm"]

FROM runtime AS development

LABEL org.opencontainers.image.title="gustavofreze/php-development" \
      org.opencontainers.image.description="PHP 8.5 FPM development runtime: runtime plus Xdebug, Composer, bash, and git"

ARG XDEBUG_VERSION=3.5.3

USER root

# The drop-ins land before the tooling install on purpose. The runtime's hardening drop-in disables
# the process functions, and PEAR calls exec() to detect the platform while it builds an extension,
# so clearing the restriction first is what keeps `pecl install` working here without weakening the
# runtime target. The opcache drop-in reuses the runtime's file name, so the development tuning
# replaces the production one instead of layering a second [opcache] section on top of it.
COPY conf/opcache.dev.ini ${PHP_INI_DIR}/conf.d/zz-gustavofreze-20-opcache.ini
COPY conf/xdebug.ini ${PHP_INI_DIR}/conf.d/zz-gustavofreze-30-xdebug.ini
COPY conf/development.ini ${PHP_INI_DIR}/conf.d/zz-gustavofreze-90-development.ini
COPY conf/fpm-development.conf /usr/local/etc/php-fpm.d/zz-gustavofreze-development.conf

RUN apk add --no-cache bash git unzip libzip \
    && apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS} linux-headers \
    && pecl install "xdebug-${XDEBUG_VERSION}" \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps \
    && rm -rf /tmp/pear

COPY --from=composer:2.9.8 /usr/bin/composer /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer

RUN install -d -o www-data -g www-data /composer \
    && git config --system --add safe.directory /var/www/html

USER www-data
