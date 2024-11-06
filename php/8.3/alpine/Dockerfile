FROM php:8.3-alpine

LABEL author="Gustavo Freze" \
      maintainer="Gustavo Freze" \
      org.label-schema.name="gustavofreze/php:8.3" \
      org.label-schema.usage="https://github.com/gustavofreze/docker-images/blob/main/php/README.md" \
      org.label-schema.vcs-url="https://github.com/gustavofreze/docker-images/blob/main/php/8.3/alpine/Dockerfile" \
      org.label-schema.schema-version="1.0"

ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"
ENV PHP_INI_DIR="/usr/local/etc/php"
ENV PHP_INI_FILE="${PHP_INI_DIR}/php.ini"

ARG PHPIZE_DEPS

RUN apk update  \
    && apk add --no-cache \
           g++ \
           git \
           tar \
           zip \
           gmp \
           curl \
           make \
           bash \
           unzip \
           openssl \
           gmp-dev \
           libzip-dev \
           linux-headers \
           ca-certificates \
           ${PHPIZE_DEPS}  \
    && pecl install xdebug  \
    && docker-php-ext-configure zip \
    && docker-php-ext-install pdo zip gmp bcmath sockets opcache pdo_mysql \
    && docker-php-ext-enable xdebug  \
    && rm -rf /var/cache/apk/* \
    && git config --global --add safe.directory '*'

ADD https://phpmd.org/static/latest/phpmd.phar /usr/local/bin/phpmd
ADD https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar /usr/local/bin/phpcs
ADD https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar /usr/local/bin/phpcbf

RUN curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --2 \
    && composer config --global github-protocols https

COPY php.ini "${PHP_INI_FILE}"
COPY xdebug.ini "${PHP_INI_DIR}/conf.d/"

RUN rm -rf /var/www/*  \
    && mkdir -p /var/www/html  \
    && chmod +x /usr/local/bin/phpcs /usr/local/bin/phpcbf /usr/local/bin/phpmd

EXPOSE 9000
