FROM php:8.3-fpm-alpine

LABEL author="Gustavo Freze" \
      maintainer="Gustavo Freze" \
      org.label-schema.name="gustavofreze/php:8.3-fpm" \
      org.label-schema.usage="https://github.com/gustavofreze/docker-images/blob/main/images/php/README.md" \
      org.label-schema.vcs-url="https://github.com/gustavofreze/docker-images/blob/main/images/php/8.3/alpine-fpm/Dockerfile" \
      org.label-schema.schema-version="1.0"

ENV LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PHP_INI_DIR="/usr/local/etc/php"

ARG PHPIZE_DEPS="autoconf dpkg-dev dpkg file g++ gcc libc-dev make pkgconf re2c"
ARG CONFIG_BASE_URL="https://raw.githubusercontent.com/gustavofreze/docker-images/main/images/php/shared/configs"

RUN set -eux; \
    apk update \
    && apk add --no-cache \
      git \
      bash \
      libzip \
      docker-cli \
      ca-certificates \
    && apk add --no-cache --virtual .build-deps \
      $PHPIZE_DEPS \
      libzip-dev \
      linux-headers \
    && docker-php-ext-install -j$(nproc) bcmath pdo pdo_mysql \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps \
    && rm -rf /tmp/* /var/cache/apk/* /root/.pearrc \
    && rm -rf /var/www/* \
    && mkdir -p /var/www/html

COPY --from=composer:2.7 /usr/bin/composer /usr/local/bin/composer

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
