FROM php:8.3-alpine

LABEL author="Gustavo Freze" \
      maintainer="Gustavo Freze" \
      org.label-schema.name="gustavofreze/php:8.3" \
      org.label-schema.usage="https://github.com/gustavofreze/docker-images/blob/main/images/php/README.md" \
      org.label-schema.vcs-url="https://github.com/gustavofreze/docker-images/blob/main/images/php/8.3/alpine/Dockerfile" \
      org.label-schema.schema-version="1.0"

ENV LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PHP_INI_DIR="/usr/local/etc/php" \
    PHP_INI_FILE="${PHP_INI_DIR}/php.ini"

ARG PHPIZE_DEPS

RUN apk add --no-cache \
        ${PHPIZE_DEPS} \
        git \
        bash \
        curl \
        docker-cli \
        libzip-dev \
        linux-headers \
        ca-certificates \
    && pecl install xdebug \
    && docker-php-ext-install -j$(nproc) bcmath pdo pdo_mysql \
    && docker-php-ext-enable xdebug \
    && apk del ${PHPIZE_DEPS} linux-headers \
    && rm -rf /tmp/* /var/cache/apk/* /root/.cache \
    && git config --global --add safe.directory '*' \
    && curl -sL https://phpmd.org/static/latest/phpmd.phar -o /usr/local/bin/phpmd \
    && curl -sL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar -o /usr/local/bin/phpcs \
    && curl -sL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar -o /usr/local/bin/phpcbf \
    && chmod +x /usr/local/bin/phpmd /usr/local/bin/phpcs /usr/local/bin/phpcbf \
    && curl -sL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --2 \
    && composer config --global github-protocols https \
    && composer clear-cache \
    && rm -rf /var/www/* \
    && mkdir -p /var/www/html

RUN curl -sL https://raw.githubusercontent.com/gustavofreze/docker-images/main/images/php/shared/configs/php-cli.ini \
        -o "${PHP_INI_FILE}" \
    && curl -sL https://raw.githubusercontent.com/gustavofreze/docker-images/main/images/php/shared/configs/xdebug.ini \
        -o "${PHP_INI_DIR}/conf.d/99-xdebug.ini"

WORKDIR /var/www/html

EXPOSE 9000
