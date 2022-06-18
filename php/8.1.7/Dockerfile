FROM php:8.1-alpine

ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"

ENV PHP_VERSION=8.1.7
ENV PHP_INI_DIR="/usr/local/etc/php"
ENV PHP_INI_FILE="${PHP_INI_DIR}/php.ini"
ENV PHP_DATE_TIMEZONE="America/Sao_Paulo"

LABEL author="Gustavo Santos" \
      maintainer="Gustavo Santos" \
      org.label-schema.name="gustavofreze/php:${PHP_VERSION}" \
      org.label-schema.usage="https://github.com/gustavofreze/docker-images/blob/main/php/README.md" \
      org.label-schema.vcs-url="https://github.com/gustavofreze/docker-images/blob/main/php/${PHP_VERSION}/Dockerfile" \
      org.label-schema.schema-version="1.0"

RUN apk update \
    && apk add --no-cache g++ zip make bash unzip autoconf ${PHPIZE_DEPS} \
    && pecl install xdebug \
    && docker-php-ext-install pdo \
    && docker-php-ext-enable xdebug \
    && docker-php-ext-install bcmath \
    && docker-php-ext-install sockets \
    && docker-php-ext-install opcache \
    && rm -rf /var/cache/apk/*

ADD https://phpmd.org/static/latest/phpmd.phar /usr/local/bin/phpmd
ADD https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar /usr/local/bin/phpcs
ADD https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar /usr/local/bin/phpcbf

RUN curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --2

COPY ./xdebug/xdebug.ini "${PHP_INI_DIR}/conf.d/"

RUN rm -rf /var/www/* \
    && mkdir -p /var/www/html \
    && mv "${PHP_INI_DIR}/php.ini-development" ${PHP_INI_FILE} \
    && sed -i "s:;date.timezone.*:date.timezone =:g" ${PHP_INI_FILE} \
    && sed -i "s:date.timezone.*:date.timezone = ${PHP_DATE_TIMEZONE}:g" ${PHP_INI_FILE} \
    && chmod +x /usr/local/bin/phpcs /usr/local/bin/phpcbf /usr/local/bin/phpmd

EXPOSE 9000
