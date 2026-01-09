# PHP

* [Quick reference](#reference)
* [Supported tags and respective Dockerfile links](#tags)
* [How to use this image?](#use)
* [Extensions and tools](#extensions)
    - [Xdebug](#xdebug)
    - [CodeSniffer](#code_sniffer)
    - [Mess Detector](#mess_detector)
    - [Composer](#composer)

<div id='reference'></div> 

## Quick reference

- **Maintained by**: [Gustavo](https://github.com/gustavofreze)

<div id='tags'></div> 

## Supported tags and respective Dockerfile links

[`8.3-alpine`](https://github.com/gustavofreze/docker-images/blob/main/images/php/8.3/alpine/Dockerfile),
[`8.3-alpine-fpm`](https://github.com/gustavofreze/docker-images/blob/main/images/php/8.3/alpine-fpm/Dockerfile),
[`8.5-alpine`]()
[`8.5-alpine-fpm`]()

<div id='use'></div> 

## How to use this image?

### CLI

#### Running directly

```shell
docker run --rm -v $(pwd):/var/www/html gustavofreze/php:8.5-alpine php your-script.php
```

#### Using as base image

Create a Dockerfile in your project:

```dockerfile
FROM gustavofreze/php:8.5-alpine
COPY . /var/www/html
WORKDIR /var/www/html
RUN composer install --no-dev --optimize-autoloader
CMD ["php", "your-script.php"]
```

Build and run:

```shell
docker build -t my-php-app .
docker run --rm my-php-app
```

### FPM (with Nginx)

Create a `docker-compose.yml`:

```yaml
services:
  php:
    image: gustavofreze/php:8.5-alpine-fpm
    volumes:
      - ./src:/var/www/html
    expose:
      - "9000"

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./src:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
```

Run:

```shell
docker compose up -d
```

<div id='extensions'></div> 

## Extensions and tools

Extensions and tools added to this image.

<div id='xdebug'></div> 

### Xdebug

[Xdebug](https://xdebug.org) is an extension for PHP, and provides a range of features to improve the PHP development
experience.

<div id='code_sniffer'></div> 

### CodeSniffer

[CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer) is a set of two PHP scripts. The main phpcs script that
tokenizes PHP, JavaScript and CSS files to detect violations of a defined coding standard, and a second phpcbf script to
automatically correct coding standard violations. CodeSniffer is an essential development tool that ensures your code
remains clean and consistent.

<div id='mess_detector'></div> 

### Mess Detector

[PHPMD](https://phpmd.org) is a mature project and provides a diverse set of pre-defined rules to detect code smells and
possible errors within the analyzed source code.

<div id='composer'></div> 

### Composer

[Composer](https://getcomposer.org) is a tool for dependency management in PHP. It allows you to declare the libraries
your project depends on, and it will manage (install/update) them for you.
