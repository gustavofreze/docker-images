---
description: Authoring rules for the public PHP and Python container base images. The image bodies, their configuration, and the verification gate all live in this repository. Nothing project-specific enters an image.
paths:
    - ".dockerignore"
    - "*.dockerignore"
    - "**/*.dockerignore"
    - "Dockerfile*"
    - "**/Dockerfile*"
    - "docker-compose*.{yml,yaml}"
    - "compose*.{yml,yaml}"
---

# Container base images

This repository is the single source for every container artifact replicable across projects.
Projects consume the published base images and add only their own dependencies, code, and tuning.
This rule covers both roles: authoring a base image here and consuming one in a project.

## Pre-output checklist

Verify every item before producing any Dockerfile, dockerignore, or compose file.

1. Every Dockerfile, base image or consumer, begins with `# syntax=docker/dockerfile:1` on its
   literal first line. See § Syntax.
2. Base images are multi-target, pinned to an exact upstream tag, and hardened. Service and
   consumer-facing targets run non-root, and ship a health check when they run a process of their
   own. Build/toolchain and one-shot/CLI targets keep root only as a named, justified exception and
   expose no port. See § Authoring.
3. Nothing is fetched from the network at build time without a pinned version and a verified
   sha256. Configuration is copied from the build context, never downloaded. See § Hermetic builds.
4. Layers are lean: one `RUN` per concern with its cache cleaned in the same layer, ephemeral build
   dependencies deleted before the layer closes, `COPY` never `ADD`, and dependency layers before
   code layers. See § Lean layers.
5. A `.dockerignore` sits next to every Dockerfile and no secret enters a build context copy.
   See § Build context.
6. Every project Dockerfile inherits `FROM` a published base image pinned to its full versioned tag,
   never a floating alias, never `latest`. See § Consuming.
7. No Dockerfile carries a comment, base image or consumer, beyond the syntax directive and an
   inline `hadolint ignore`. Rationale lives in § Where the reasoning lives and the family README.
8. No project re-declares what the base already provides. See § What the base provides.
9. Compose files declare no `version:` key. Every long-running service has resource limits and a
   health signal. See § Compose.

## Syntax

Every Dockerfile begins with `# syntax=docker/dockerfile:1` as its literal first line, the base
images here and the thin consumer files in a project alike. It pins the stable BuildKit frontend so
build-time mounts, secrets, and heredocs parse identically on every machine and in CI. The directive
is the one line that is not a build instruction and, in a consumer Dockerfile, the one line that is
not a comment-free instruction either.

## What the base provides

The PHP base (`gustavofreze/php`, four targets) bakes in everything below. A project Dockerfile that
restates any of these is wrong:

- Extensions: the official image set plus `bcmath`, `pdo_mysql`, and `zip`, with no leftover build
  dependencies.
- Non-root runtime: PHP-FPM runs as `www-data`, `WORKDIR /var/www/html` owned by it.
- Hardening: `php.ini-production` active and the development template deleted, `expose_php` and
  `display_errors` off, `allow_url_include` off, arguments stripped from exception traces, strict and
  transport-locked session cookies, and the process escape functions disabled.
- OPcache defaults: production tuning in `runtime`, development tuning in `development`.
- A container health check probing the FPM socket, and graceful shutdown through the official
  `STOPSIGNAL SIGQUIT` plus a 10s `process_control_timeout`.
- Development tooling (Xdebug, Composer, bash, git) in the `development` target only.
- A `cli` tooling variant (Composer, Xdebug coverage, CodeSniffer, Mess Detector, docker CLI)
  consumed by a project Makefile, never by a Dockerfile.

The Python base (`gustavofreze/python`, four targets) bakes in the `app` user (uid 1000) with
`WORKDIR /app`, the project-local virtual environment on `PATH` with `VIRTUAL_ENV` set, the
container-correct interpreter defaults (`PYTHONUNBUFFERED`, `PYTHONDONTWRITEBYTECODE`,
`PYTHONFAULTHANDLER`), and a pinned cacheless pip. Poetry and the C toolchain live in `builder` and
`cli`, Poetry and debugpy in `development`, and neither reaches `runtime`.

## Stage vocabulary and tags

Four stage names are the closed vocabulary. Each names what the image is, and a family ships only the
stages its role calls for.

- **`builder`**. The compilation base a project inherits via `FROM`. It carries the toolchain that
  installs dependencies and compiles them, and the multi-stage build discards it.
- **`runtime`**. The production image the platform runs.
- **`cli`**. Local command-line tooling for one-shot commands, invoked from a project Makefile.
- **`development`**. A variant of `runtime` built `FROM runtime`, adding local development tooling.
  It runs on a developer machine and is never deployed. It is subordinate to `runtime`, not a peer.

Every published tag is `<upstream-minor>-<role>-<semver>`, where `role` is identical to the stage
name. There is no bare tag: a role always sits between the upstream minor and the semantic version.
Version tags are immutable, so any input change bumps the build unit `VERSION`. `latest` is
forbidden. Each stage also carries one floating alias `<upstream-minor>-<role>` that the weekly
security rebuild repoints at a freshly pulled upstream base. A project always pins the full versioned
tag.

## Version layer

Each family keeps one build unit per upstream minor, under an `<upstream-minor>/` subdirectory
(`images/php/8.5/`, `images/python/3.14/`). The subdirectory segment is the exact minor read from the
Dockerfile `FROM` pin. A build unit is self-contained: its own `Dockerfile`, `VERSION`,
configuration, baked scripts, `.dockerignore`, and `scripts/smoke`, with a semantic version that
advances independently of every other upstream version.

Two kinds of upstream change move differently:

- **Minor or major bump** (PHP 8.5 to 8.6). The Dockerfile and its configuration diverge, so the new
  version is a new sibling subdirectory that starts its own `VERSION` at `1.0.0`. The two lines
  publish in parallel and coexist, and each project migrates on its own schedule. Nothing in the old
  subdirectory changes.
- **Patch bump** (PHP 8.5.9 to 8.5.10). The upstream pin and the `VERSION` both move inside the same
  subdirectory. No new directory appears, and the floating alias tracks the new patch.

To add an upstream version, copy the current subdirectory to a new `<upstream-minor>/` beside it,
repoint its Dockerfile `FROM` to the new upstream pin (honoring the 7-day cooldown), reset its
`VERSION` to `1.0.0`, adjust the configuration the new upstream requires, and wire its build, lint,
scan, audit, efficiency, smoke, and publish steps into the Makefile beside the existing version.

## Dependency policy

NEVER pin an upstream image tag or a tool release published less than 7 days ago. Verify the
publication date before adopting one. This covers the base image and every pinned tool alike
(Composer, Xdebug, CodeSniffer, Mess Detector, pip, Poetry, debugpy).

Alpine package versions are the one deliberate exception to exact pinning: the Alpine repository is
rolling and drops old versions, so a pinned `apk` version breaks reproducibility instead of improving
it. The exact upstream image tag (patch version and distro release) is the reproducibility boundary,
which is why DL3018 is relaxed in `.hadolint.yaml` and nothing else is.

## Hermetic builds

A build reads its inputs from the build context and from pinned, verified sources. Nothing else.

- Configuration files are `COPY`ed from the build unit's `conf/` directory. Downloading a `.ini` from
  a branch URL at build time makes the image depend on the state of a remote branch, produces a
  different image from the same source on a different day, and offers no integrity check. It is
  forbidden.
- A remote artifact (a phar, a release tarball) is fetched to a scratch path with an exact version in
  the URL, verified against a sha256 recorded as an `ARG` in the Dockerfile, and only then installed
  onto `PATH`. An unverified artifact is never executable inside the image, not even between two
  instructions.
- `ADD` is never used. It also fetches URLs and unpacks archives, which hides what enters the image.

## Lean layers

Every layer carries only what the image keeps. One `RUN` groups a single concern and cleans up after
itself in the same layer, so nothing it fetched survives into the image:

- Package installs use the no-cache mode of the package manager, and build-only dependencies are
  installed under a virtual group and deleted (`apk add --virtual .build-deps … && … && apk del
  .build-deps`) before the `RUN` ends. A tool removed in a later layer still occupies the earlier
  one, so the removal and the install share a layer. The `builder` target is the deliberate
  exception: it keeps the toolchain, because carrying it is the whole point of that target.
- `COPY` moves files in, never `ADD`.
- Dependency layers come before code layers so a code change does not invalidate the dependency
  cache.

The efficiency stage of the review gate holds these to the thresholds in `.dive-ci`. A widening layer
is a signal to prune the `RUN`, not to relax the threshold.

## Authoring

Every image family lives under `images/`, one directory per family, each holding one self-contained
build unit per upstream minor under an `<upstream-minor>/` subdirectory. Each build unit ships a
single `Dockerfile` with the targets it needs, a `VERSION` file, its configuration or baked scripts,
a `.dockerignore`, and a `scripts/smoke` assertion script. A family `README.md` sits one level up as
the umbrella.

Every base Dockerfile matches its siblings on all of these:

1. The literal first line is `# syntax=docker/dockerfile:1`.
2. No comment anywhere else. The only other `#` line permitted is an inline `hadolint ignore=<rule>`
   directive, which is a lint instruction and not a comment. See § Where the reasoning lives.
3. A full OCI label set (`title`, `description`, `vendor`, `authors`, `licenses`, `url`, `source`,
   `documentation`) on each target built from a distinct upstream base, and a `title` and
   `description` override on each derived target.
4. Targets ordered base to derivative, never a derivative before the stage it builds on.
5. A uniform package pattern: no-cache installs, build-only dependencies in a virtual group deleted
   in the same `RUN`, one `RUN` per concern chained with `&&`.
6. A non-root last `USER` on every target an application runs, with `WORKDIR` owned by that user and
   only unprivileged ports exposed. A target that legitimately stays root is the documented,
   justified exception, carries an inline `hadolint ignore=DL3002` on the `USER root` line, and is
   audited with the matching CIS exemption named in the Makefile.
7. A `HEALTHCHECK` on every target that starts a long-running process of its own, and none on the
   targets with nothing to probe (a builder base, a language runtime, a one-shot tooling image).
   A target with no health check is audited with the CIS-DI-0006 exemption, named in the Makefile.
8. Baked drop-in configuration is namespaced and numbered (`zz-gustavofreze-<NN>-*` in a `conf.d`),
   so it layers over the upstream defaults in a predictable order and a derived target can replace a
   single drop-in by reusing its file name.
9. A baked executable script lives at one canonical path, `/usr/local/bin/<name>`, copied with
   `COPY --chmod=755`, carrying a shebang as its first line, and sourced from the family's `bin/`.
   Every reference to it uses that same path.

## Where the reasoning lives

Dockerfiles here carry no prose. The rationale for a non-obvious instruction lives in this section
and in the family README, so it is written once instead of drifting between a comment and a document.
Read this before reordering or simplifying an instruction: each item below is load bearing, and the
build or the gate breaks when it is undone.

- **The PHP `development` drop-ins are `COPY`ed before the `pecl install` that follows them.** The
  runtime's hardening drop-in disables the process functions, and PEAR calls `exec()` while building
  an extension, so the install fails with a fatal in `OS/Guess.php` if the ordering is swapped for
  cache reasons. `conf/development.ini` clears `disable_functions`, which is what makes it work.
- **The `development` OPcache drop-in reuses the runtime's file name.** That replaces the production
  tuning instead of stacking a second `[opcache]` section on top of it. Renaming it silently keeps
  production tuning active in the development image.
- **Drop-ins are numbered because PHP reads `conf.d` alphabetically.** Hardening is `10`, the
  development and cli overrides are `90`. An override numbered below the hardening file loses.
- **`conf/fpm-shutdown.conf` opens `[global]` and then reopens `[www]`.** The alphabetical
  `php-fpm.d` include order reaches it with the `[www]` pool of `zz-docker.conf` still open, and
  `conf/fpm-development.conf` relies on that pool still being open when it is read.
- **The Python `runtime` uninstalls pip on purpose.** It is the largest dependency tree in the image
  and nothing in it is reachable from an application running the virtual environment the builder
  populated. The `ensurepip` wheel stays as the way back. `scan-python` audits this target with no
  ignore file, so restoring pip here fails the gate.
- **The Python `builder` keeps its C toolchain on purpose.** It is the stage an application compiles
  wheels in, so pruning it only moves the same install into the consuming Dockerfile.
- **The `cli` targets end as root on purpose.** They are invoked over a bind mount owned by the
  caller and must write into it. That is why each carries `hadolint ignore=DL3002` and is audited
  with the CIS-DI-0001 exemption.
- **Each phar is fetched to a scratch path and installed onto `PATH` only after `sha256sum -c`
  passes,** so an unverified artifact is never executable, not even between two instructions.
- **`phpmd` on `PATH` is a wrapper, not the phar.** The phar sits at `/usr/local/lib/phpmd.phar` and
  the wrapper silences the deprecation notices PHPMD 2.15.0 raises on PHP 8.5, keeping stdout
  parseable.
- **`${PHPIZE_DEPS}` is deliberately unquoted.** It is a space-separated package list that must word
  split, which is why SC2086 is relaxed in `.hadolint.yaml`.

Every change runs the review gate (`make review`: lint, build, scan, audit, efficiency, smoke) before
publication, and any input change bumps `VERSION`. A vulnerability finding that cannot be fixed
locally is accepted only through a suppression scoped to the single family it affects, carrying a
written justification and a revisit condition, never a repository-wide one.

## Smoke contract

`scripts/smoke` boots a throwaway container per target and asserts what that target's class promises.
It sources the shared host-side helper library (`scripts/smoke-lib.sh`, resolved through the
`SMOKE_LIB` path the Makefile exports) and adds only the family-specific assertions.

- **Service target**: runs as a non-root user, its baked health check drives the container to a
  healthy state, no build tooling or development tooling survives into the production surface, the
  hardening is active, and the pinned versions are present.
- **Builder target**: its toolchain versions are pinned and present, it runs non-root, and its
  working directory is the expected application root.
- **One-shot or CLI target**: its pinned tools answer `--version`, and its working directory is the
  expected application root.

A target that quietly reverted to root, lost its hardening, or drifted off a pinned version fails its
own smoke.

## Build context

Every Dockerfile has a `.dockerignore` beside it covering at least `.git`, IDE directories, the
`Dockerfile` and `.dockerignore` themselves, `*.md`, `VERSION`, and `scripts/`. In a project, add
`.env` and `.env.local`. Secrets never enter a build context copy.

## Secrets

No secret is embedded in any image layer or versioned compose file. Build-time credentials enter
through a BuildKit secret (`RUN --mount=type=secret,id=<name>`) and the caller passes
`--secret id=<name>,env=<VAR>`. Runtime configuration enters through environment variables, never
through files baked into the image.

## Consuming

A project consumes the base in two thin files:

- `Dockerfile.dev`: `FROM gustavofreze/<family>:<minor>-development-<V>` plus a `COPY` of the code.
- `Dockerfile.prod`: a builder stage `FROM gustavofreze/<family>:<minor>-builder-<V>` installing
  dependencies, then a runtime stage `FROM gustavofreze/<family>:<minor>-runtime-<V>` copying the
  built tree with the runtime user's ownership.

A project adds only its own dependencies, code, and tuning. Dependency layers come before code layers
so the cache survives code changes.

A consumer Dockerfile carries no comment, like the base images it inherits. The only line that is not
a build instruction is the `# syntax=docker/dockerfile:1` directive. The reasoning behind each step
lives in the base image it inherits and in this rule, never copied into the project.

The `cli` image needs no Dockerfile at all. It is referenced by a project Makefile variable and
invoked over a bind mount.

## Compose

No `version:` key (deprecated). Every long-running service declares `cpus` and `mem_limit`. Services
whose image ships a `HEALTHCHECK` inherit it, other long-running services declare a `healthcheck:`
block. One-shot jobs are exempt. Databases persist on named volumes prefixed with the service name.
Secrets reach containers through `env_file:` entries pointing at gitignored files, never through
values committed in the compose file.
