# gustavofreze/php

Hardened, reproducible PHP base images. One Dockerfile per upstream version ships four targets: the production `runtime`
(PHP-FPM), its `development` variant, the `builder` toolchain for a project's production build, and a `cli` tooling
image a project Makefile invokes. Non-root and hardened where an application runs it, root only where a local tooling
image needs to write into a bind mount.

* [Quick reference](#quick-reference)
* [Supported tags](#supported-tags)
* [Image variants](#image-variants)
* [What it provides](#what-it-provides)
* [How to use this image](#how-to-use-this-image)
* [Verification](#verification)
* [License](#license)

## Quick reference

- **Maintained by:** [Gustavo Freze](https://github.com/gustavofreze)
- **Source:** [gustavofreze/docker-images](https://github.com/gustavofreze/docker-images)
- **File an issue:** [docker-images/issues](https://github.com/gustavofreze/docker-images/issues)
- **Also published as:** `ghcr.io/gustavofreze/php`
- **Architectures:** `linux/amd64`, `linux/arm64`
- **Supply chain:** every tag ships a build provenance attestation, an SBOM, and an OpenVEX analysis
- **License:** [MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)

## Supported tags

Every tag is `<upstream-minor>-<target>-<version>`. There is no bare tag and `latest` is forbidden. Version tags are
immutable, so any change to a Dockerfile or its inputs publishes a new `<version>` instead of rewriting one. Each
target also carries a floating alias, and a project may take either form.

| Tag                     | Alias             | Target        | Purpose                                                         |
|:------------------------|:------------------|:--------------|:----------------------------------------------------------------|
| `8.5-runtime-1.0.1`     | `8.5-runtime`     | `runtime`     | Production PHP-FPM runtime.                                     |
| `8.5-development-1.0.1` | `8.5-development` | `development` | Development runtime: runtime plus Xdebug, Composer, bash, git.  |
| `8.5-builder-1.0.1`     | `8.5-builder`     | `builder`     | Composer toolchain for the builder stage of a production image. |
| `8.5-cli-1.0.1`         | `8.5-cli`         | `cli`         | Makefile tooling: Composer, Xdebug coverage, linters, docker.   |

All four are built from one multi-target
[Dockerfile](https://github.com/gustavofreze/docker-images/blob/main/images/php/8.5/Dockerfile), pinned to
`php:8.5.9-fpm-alpine3.24`. The alias tracks the latest rebuild of its target and never crosses an upstream minor, so
`8.5-runtime` stays on 8.5. Take the versioned tag for anything that ships, because it is reproducible and moves only
when you bump it. Take the alias when the weekly security rebuild arriving without a pull request is worth more than
that, which is usually the case for `cli` and for local development. An alias moves only when the client re-pulls.

## Image variants

`development` is subordinate to `runtime`, built `FROM runtime`. It runs on a developer machine and is never deployed.
`runtime`, `development`, and `builder` all drop to `www-data` (uid 82), and `runtime` and `development` ship a health
check on the FPM socket. The `builder` is discarded in the multi-stage application build, so the build stage installs
dependencies non-root and the vendor tree it produces already carries the runtime's ownership. The `cli` is a root-only
tooling image so it can write into a bind mount owned by the caller.

The FPM base is 36MB lighter than the CLI base (it omits the `php-cgi` and `phpdbg` SAPIs, which nothing here uses)
while still shipping the CLI SAPI that Composer and the linters run on, and building every target on it means the whole
family shares one base layer instead of pulling two. The one visible consequence is that `builder` and `cli` inherit the
base's `EXPOSE 9000`. It is metadata only, nothing in either image listens, and their default command is the interactive
PHP shell.

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- Extensions: the official image set (curl, sodium, mbstring, and the rest) plus `bcmath`, `pdo_mysql`, and `zip`, built
  with no leftover build dependencies.
- A non-root runtime: PHP-FPM runs as `www-data`, `WORKDIR /var/www/html` owned by it.
- Production hardening: `php.ini-production` active (the development template is deleted), `expose_php` and
  `display_errors` off, `allow_url_include` off, arguments stripped from exception traces, strict and transport-locked
  session cookies, and the process escape functions (`exec`, `shell_exec`, `system`, `proc_open`, `popen`, `passthru`)
  disabled. A project that legitimately shells out re-enables what it needs in its own drop-in.
- OPcache defaults: production tuning in `runtime` (no timestamp validation, tracing JIT), development tuning in
  `development` (timestamp validation on, JIT off).
- A container health check probing the PHP-FPM socket.
- Graceful shutdown: the official `STOPSIGNAL SIGQUIT` and exec-form `php-fpm` command are preserved, and
  `process_control_timeout` is set to 10s, so on stop the master drains in-flight requests before escalating, inside the
  10s default stop timeout of `docker stop` and Compose.
- In `development` only: Xdebug 3.5.3, Composer 2.10.2, bash, git, undecorated worker output in `docker logs`, and the
  process functions re-enabled so Composer can run.

The `builder` image carries Composer 2.10.2, git, and unzip. The `cli` variant adds Xdebug coverage, bash, curl, and the
pinned linters (CodeSniffer 4.0.1 as `phpcs` and `phpcbf`, Mess Detector 2.15.0 as `phpmd`), each fetched over TLS and
verified against its published sha256 before it enters a layer.

The `cli` variant also ships the docker CLI, so an integration suite that drives throwaway containers can shell out to
`docker` against a mounted host socket. It is the only image in this repository that carries it: `builder` and `runtime`
assert its absence. Mounting the socket is root-equivalent on the host, so grant it only to a local tooling invocation
you control.

Two details make the `cli` image safe to pipe. Diagnostics go to `stderr`, never `stdout`, so a `--report=json` run is
parseable. And `phpmd` is a wrapper around the phar that silences the deprecation notices PHPMD 2.15.0 (released in
2023, still the newest) raises on PHP 8.5, so its report is the only thing on either stream.

## How to use this image

### As a base image

A project consumes the base in two thin files and adds only its own dependencies, code, and tuning:

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/php:8.5-development-1.0.1
COPY ./ /var/www/html
```

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/php:8.5-builder-1.0.1 AS builder
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader
COPY ./ ./
RUN composer dump-autoload --optimize --classmap-authoritative

FROM gustavofreze/php:8.5-runtime-1.0.1
COPY --from=builder --chown=www-data:www-data /var/www/html /var/www/html
```

### As a tooling image

The `cli` image is invoked directly and never appears in a Dockerfile:

```shell
docker run --rm -v "$(pwd)":/var/www/html gustavofreze/php:8.5-cli-1.0.1 composer install
docker run --rm -v "$(pwd)":/var/www/html gustavofreze/php:8.5-cli-1.0.1 phpcs src/
```

### As an FPM service

```yaml
services:
    php:
        image: gustavofreze/php:8.5-development-1.0.1
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

The rules that hold across every family live in the
[usage contract](https://github.com/gustavofreze/docker-images#usage-contract).

## Verification

No tag is published before it passes the full gate: hadolint and ShellCheck on every Dockerfile and `RUN` body, a Trivy
and Grype scan for fixable HIGH and CRITICAL vulnerabilities, a Dockle audit against the CIS Docker Benchmark, a dive
layer-efficiency check, and a smoke suite that boots throwaway containers and asserts the runtime contract (non-root
user, extensions present, hardening active, OPcache mode, health check, pinned tool versions, and no development tooling
in the production surface). The gate runs on a native `linux/amd64` runner and a native `linux/arm64` one, so every
architecture that ships was actually built, scanned, audited, and smoke-tested.

Every tag also carries an [OpenVEX](https://openvex.dev) analysis as a cosign attestation, stating per CVE whether the
image is genuinely affected. A scanner that reads it applies the analysis on its own:

```shell
trivy image --vex oci gustavofreze/php:8.5-cli-1.0.1
```

Today it covers the Go standard library compiled into the docker CLI that `cli` carries. Those statements are
`affected`, not `not_affected`: the code is present, Go has fixed it, and no docker CLI image built with the fixed
toolchain has been published yet. They are reported rather than silenced, which is the point. Whether the local gate
stops on one is a separate decision, recorded in
[.trivy/php.yaml](https://github.com/gustavofreze/docker-images/blob/main/.trivy/php.yaml) with the date it was accepted
and an expiry, and never mixed into the analysis. The document is also versioned at
[vex/php.openvex.json](https://github.com/gustavofreze/docker-images/blob/main/vex/php.openvex.json), so it can be
passed as a file or a URL.

The reasoning behind each pin, exemption, and threshold is written in the
[repository README](https://github.com/gustavofreze/docker-images#self-verification).

## License

[MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)
