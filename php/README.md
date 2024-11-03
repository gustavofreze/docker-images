# PHP

* [Quick reference](#reference)
* [Supported tags and respective Dockerfile links](#tags)
* [What is PHP?](#php)
* [How to use this PHP?](#use)
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

- [`8.1`](https://github.com/gustavofreze/docker-images/blob/main/php/8.1/alpine/Dockerfile),
  [`8.2`](https://github.com/gustavofreze/docker-images/blob/main/php/8.2/alpine/Dockerfile),
  [`8.3`](https://github.com/gustavofreze/docker-images/blob/main/php/8.3/alpine/Dockerfile),
  [`latest`](https://github.com/gustavofreze/docker-images/blob/main/php/latest/alpine/Dockerfile),
  [`8.1-fpm`](https://github.com/gustavofreze/docker-images/blob/main/php/8.1/alpine-fpm/Dockerfile),
  [`8.2-fpm`](https://github.com/gustavofreze/docker-images/blob/main/php/8.2/alpine-fpm/Dockerfile),
  [`8.3-fpm`](https://github.com/gustavofreze/docker-images/blob/main/php/8.3/alpine-fpm/Dockerfile),
  [`latest-fpm`](https://github.com/gustavofreze/docker-images/blob/main/php/latest/alpine-fpm/Dockerfile)

<div id='php'></div> 

## What is PHP?

[PHP](https://www.php.net) is a widely used open source general-purpose scripting language especially suited for
web development.

<div id='use'></div> 

## How to use this image?

Create a Dockerfile in your project:

```dockerfile
FROM gustavofreze/php
COPY . /usr/src/myapp
WORKDIR /usr/src/myapp
```

You can then run and build the Docker image:

```shell
docker build -t my-php-app .
```

After the image is built:

```shell
docker run -it --rm --name my-running-app my-php-app
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
