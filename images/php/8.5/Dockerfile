# syntax=docker/dockerfile:1

# PHP base images. Four build targets, built and tagged by the repository Makefile.
#
#   builder      Composer build toolchain for the builder stage of an application image.
#   runtime      Hardened production PHP-FPM runtime. No build tools, no dev tooling, non-root.
#   development  Runtime plus Xdebug, Composer, bash, git, and development OPcache settings.
#   cli          Local tooling image invoked from a project Makefile, never inherited by a Dockerfile.

FROM php:8.5.9-cli-alpine3.24 AS builder

LABEL org.opencontainers.image.title="gustavofreze/php-builder" \
      org.opencontainers.image.description="PHP 8.5 Composer build toolchain for application builder stages" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/php/README.md"

RUN apk add --no-cache ca-certificates git unzip libzip \
    && apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS} linux-headers libzip-dev \
    && docker-php-ext-install -j"$(nproc)" bcmath pdo_mysql zip \
    && apk del .build-deps \
    && mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"

COPY --from=composer:2.10.2 /usr/bin/composer /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer

WORKDIR /var/www/html

# Drops to www-data, the uid the runtime runs as, so the vendor tree a build stage produces already
# carries the runtime's ownership.
RUN install -d -o www-data -g www-data /composer \
    && chown www-data:www-data /var/www/html \
    && git config --system --add safe.directory /var/www/html

USER www-data

FROM builder AS cli

LABEL org.opencontainers.image.title="gustavofreze/php-cli" \
      org.opencontainers.image.description="PHP 8.5 CLI tooling image: Composer, Xdebug coverage, CodeSniffer, Mess Detector, docker CLI"

ARG PHPMD_VERSION=2.15.0
ARG PHPCS_VERSION=4.0.1
ARG XDEBUG_VERSION=3.5.3
ARG PHPMD_SHA256=6a28ef55de0c753b070d1d1580bb08a0d146016f89f0eddcef60ac4fc1083544
ARG PHPCS_SHA256=a211817baf28918b2cff8e80af5d53d7e7060f9761384c0d9df0f003afb51a40
ARG PHPCBF_SHA256=2b6c98c48eafc2e211cec397a0e9693010b09791760b93eef2606b38df5351af

# Root on purpose: this image is invoked over a bind mount owned by the caller and must write into
# it. One-shot, no exposed port, audited with the CIS-DI-0001 exemption. DL3002 is the lint side of
# that exception, ignored here so it stays active on every target that must end non-root.
# hadolint ignore=DL3002
USER root

RUN apk add --no-cache bash curl docker-cli \
    && apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS} linux-headers \
    && pecl install "xdebug-${XDEBUG_VERSION}" \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps \
    && rm -rf /tmp/pear

# Each phar reaches PATH only after its sha256 matches, so an unverified artifact is never
# executable inside the image, not even between two instructions.
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

# The phar sits off PATH behind this wrapper, which silences the deprecation notices the 2023 code
# base of PHPMD 2.15.0 raises on PHP 8.5.
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

# The development template is deleted, so a rename inside a consuming image cannot bring the loose
# defaults back.
RUN apk add --no-cache ca-certificates libzip \
    && apk add --no-cache --virtual .build-deps ${PHPIZE_DEPS} linux-headers libzip-dev \
    && docker-php-ext-install -j"$(nproc)" bcmath pdo_mysql zip \
    && apk del .build-deps \
    && mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini" \
    && rm -f "${PHP_INI_DIR}/php.ini-development"

# Numbered because PHP loads conf.d alphabetically: hardening (10) must land before the development
# override (90).
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

# The drop-ins land before the install because the runtime's hardening disables the process
# functions and PEAR calls exec() while building an extension. The opcache file reuses the runtime's
# name, so it replaces that tuning instead of stacking a second section on top of it.
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

COPY --from=composer:2.10.2 /usr/bin/composer /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer

RUN install -d -o www-data -g www-data /composer \
    && git config --system --add safe.directory /var/www/html

USER www-data
