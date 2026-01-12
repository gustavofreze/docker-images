FROM php:8.5-fpm-alpine

LABEL org.opencontainers.image.url="https://github.com/gustavofreze/docker-images"
LABEL org.opencontainers.image.title="gustavofreze/php:8.5-alpine-fpm"
LABEL org.opencontainers.image.source="https://github.com/gustavofreze/docker-images"
LABEL org.opencontainers.image.authors="Gustavo Freze"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.description="PHP 8.5 FPM Alpine image for development"
LABEL org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/php/README.md"

ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"
ENV PHP_INI_DIR="/usr/local/etc/php"

ARG CONFIG_BASE_URL="https://raw.githubusercontent.com/gustavofreze/docker-images/main/images/php/shared/configs"

RUN set -eux; \
    apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      git=2.52.0-r0 \
      bash=5.3.3-r1 \
      libzip=1.11.4-r1 \
      docker-cli=29.1.3-r0 \
      ca-certificates=20251003-r0 \
    && apk add --no-cache --virtual .build-deps \
      autoconf=2.72-r1 \
      dpkg-dev=1.22.21-r0 \
      dpkg=1.22.21-r0 \
      file=5.46-r2 \
      g++=15.2.0-r2 \
      gcc=15.2.0-r2 \
      musl-dev=1.2.5-r21 \
      make=4.4.1-r3 \
      pkgconf=2.5.1-r0 \
      re2c=4.3.1-r0 \
      libzip-dev=1.11.4-r1 \
      linux-headers=6.16.12-r0 \
    && docker-php-ext-install -j"$(nproc)" bcmath pdo pdo_mysql \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps \
    && rm -rf /tmp/* /var/cache/apk/* /root/.pearrc \
    && rm -rf /var/www/* \
    && mkdir -p /var/www/html

COPY --from=composer:2.9 /usr/bin/composer /usr/local/bin/composer

RUN set -eux \
    && git config --global --add safe.directory '*' \
    && composer config --global github-protocols https \
    && curl -sfSL https://phpmd.org/static/latest/phpmd.phar -o /usr/local/bin/phpmd \
    && curl -sfSL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar -o /usr/local/bin/phpcs \
    && curl -sfSL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar -o /usr/local/bin/phpcbf \
    && chmod +x /usr/local/bin/phpmd /usr/local/bin/phpcs /usr/local/bin/phpcbf

WORKDIR /var/www/html

RUN set -eux \
    && curl -sfSL "${CONFIG_BASE_URL}/php-fpm.ini" -o "${PHP_INI_DIR}/php.ini" \
    && curl -sfSL "${CONFIG_BASE_URL}/xdebug.ini" -o "${PHP_INI_DIR}/conf.d/99-xdebug.ini"

EXPOSE 9000
