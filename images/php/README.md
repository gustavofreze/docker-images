# PHP base images

The base a PHP project builds `FROM`. One Dockerfile per upstream version ships four targets: the
production `runtime` (PHP-FPM), its `development` variant, the `builder` toolchain for a project's
production build, and a `cli` tooling image a project Makefile invokes. Non-root and hardened where
an application runs it, root only where a local tooling image needs to write into a bind mount.

* [Available versions](#versions)
* [Targets and tags](#targets)
* [What it provides](#provides)
* [Usage](#usage)

<div id='versions'></div>

## Available versions

Each upstream version is a self-contained build unit under `<upstream-minor>/`, with its own
Dockerfile, `VERSION`, configuration, and smoke script, versioned independently. See the repository
README, section Versioning.

| Upstream minor | Build unit         | Base version | Upstream pin             |
|:---------------|:-------------------|:-------------|:-------------------------|
| 8.5            | `images/php/8.5/`  | `1.0.0`      | `php:8.5.9-*-alpine3.24` |

<div id='targets'></div>

## Targets and tags

Every published tag is `gustavofreze/php:<upstream-minor>-<role>-<V>`, immutable, `latest`
forbidden. Each target also carries a floating alias `<upstream-minor>-<role>` that tracks its
latest rebuild. Pin the full versioned tag.

| Image                                   | Target        | Purpose                                                          |
|:----------------------------------------|:--------------|:-----------------------------------------------------------------|
| `gustavofreze/php:8.5-runtime-1.0.0`     | `runtime`     | Production PHP-FPM runtime.                                      |
| `gustavofreze/php:8.5-development-1.0.0` | `development` | Development runtime: runtime plus Xdebug, Composer, bash, git.   |
| `gustavofreze/php:8.5-builder-1.0.0`     | `builder`     | Composer toolchain for the builder stage of a production image.  |
| `gustavofreze/php:8.5-cli-1.0.0`         | `cli`         | Makefile tooling: Composer, Xdebug coverage, linters, docker CLI. |

`development` is subordinate to `runtime`, built `FROM runtime`. It runs on a developer machine and
is never deployed. `runtime`, `development`, and `builder` all drop to `www-data` (uid 82), and
`runtime` and `development` ship a health check on the FPM socket. The `builder` is discarded in the
multi-stage application build, so the build stage installs dependencies non-root and the vendor tree
it produces already carries the runtime's ownership. The `cli` is a root-only tooling image so it can
write into a bind mount owned by the caller, audited with the CIS-DI-0001 exemption. The only port in
play is the 9000 the upstream FPM image exposes, which is unprivileged.

<div id='provides'></div>

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- Extensions: the official image set (curl, sodium, mbstring, and the rest) plus `bcmath`,
  `pdo_mysql`, and `zip`, built with no leftover build dependencies.
- A non-root runtime: PHP-FPM runs as `www-data`, `WORKDIR /var/www/html` owned by it.
- Production hardening: `php.ini-production` active (the development template is deleted),
  `expose_php` and `display_errors` off, `allow_url_include` off, arguments stripped from exception
  traces, strict and transport-locked session cookies, and the process escape functions (`exec`,
  `shell_exec`, `system`, `proc_open`, `popen`, `passthru`) disabled. A project that legitimately
  shells out re-enables what it needs in its own drop-in.
- OPcache defaults: production tuning in `runtime` (no timestamp validation, tracing JIT),
  development tuning in `development` (timestamp validation on, JIT off).
- A container health check probing the PHP-FPM socket (`bin/php-fpm-healthcheck`).
- Graceful shutdown: the official `STOPSIGNAL SIGQUIT` and exec-form `php-fpm` command are
  preserved, and `conf/fpm-shutdown.conf` sets `process_control_timeout = 10s`, so on stop the master
  drains in-flight requests before escalating, inside the 10s default stop timeout of `docker stop`
  and Compose.
- In `development` only: Xdebug 3.5.3, Composer 2.9.8, bash, git, undecorated worker output in
  `docker logs`, and the process functions re-enabled so Composer can run.

The `builder` image carries Composer 2.9.8, git, and unzip. The `cli` variant adds Xdebug coverage,
the docker CLI, bash, and the pinned linters (CodeSniffer 4.0.1 as `phpcs` and `phpcbf`, Mess
Detector 2.15.0 as `phpmd`), each fetched over TLS and verified against its published sha256 before
it enters a layer.

Two details make the `cli` image safe to pipe. Diagnostics go to `stderr`, never `stdout`, so a
`--report=json` run is parseable. And `phpmd` is a wrapper around the phar that silences the
deprecation notices PHPMD 2.15.0 (released in 2023, still the newest) raises on PHP 8.5, so its
report is the only thing on either stream.

<div id='usage'></div>

## Usage

### As a base image

A project consumes the base in two thin files and adds only its own dependencies, code, and tuning:

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/php:8.5-development-1.0.0
COPY ./ /var/www/html
```

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/php:8.5-builder-1.0.0 AS builder
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader
COPY ./ ./
RUN composer dump-autoload --optimize --classmap-authoritative

FROM gustavofreze/php:8.5-runtime-1.0.0
COPY --from=builder --chown=www-data:www-data /var/www/html /var/www/html
```

### As a tooling image

The `cli` image is invoked directly and never appears in a Dockerfile:

```shell
docker run --rm -v "$(pwd)":/var/www/html gustavofreze/php:8.5-cli-1.0.0 composer install
docker run --rm -v "$(pwd)":/var/www/html gustavofreze/php:8.5-cli-1.0.0 phpcs src/
```

### As an FPM service

```yaml
services:
    php:
        image: gustavofreze/php:8.5-development-1.0.0
        volumes:
            - ./:/var/www/html
        expose:
            - "9000"

    nginx:
        image: nginx:alpine
        ports:
            - "80:80"
        volumes:
            - ./public:/var/www/html/public
            - ./nginx.conf:/etc/nginx/conf.d/default.conf
        depends_on:
            - php
```

The full consumption rules live in the repository README, section Usage contract.
