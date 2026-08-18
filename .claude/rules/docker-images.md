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

This repository is the single source for every container artifact replicable across projects. Projects consume the
published base images and add only their own dependencies, code, and tuning. This rule covers both roles: authoring a
base image here and consuming one in a project.

## Pre-output checklist

Verify every item before producing any Dockerfile, dockerignore, or compose file.

1. Every Dockerfile, base image or consumer, begins with `# syntax=docker/dockerfile:1` on its literal first line.
   See § Syntax.
2. Base images are multi-target, pinned to an exact upstream tag, and hardened. Service and consumer-facing targets run
   non-root, and ship a health check when they run a process of their own. Build/toolchain and one-shot/CLI targets keep
   root only as a named, justified exception that starts no long-running process. See § Authoring.
3. Nothing is fetched from the network at build time without a pinned version and a verified sha256. Configuration is
   copied from the build context, never downloaded. See § Hermetic builds.
4. Layers are lean: one `RUN` per concern with its cache cleaned in the same layer, ephemeral build dependencies deleted
   before the layer closes, `COPY` never `ADD`, and dependency layers before code layers. See § Lean layers.
5. A `.dockerignore` sits next to every Dockerfile and no secret enters a build context copy. See § Build context.
6. Every project Dockerfile inherits `FROM` a published base image by its full versioned tag or by its floating
   `<upstream-minor>-<role>` alias, never `latest`. Anything that ships takes the versioned tag. See § Consuming.
7. No Dockerfile carries a comment, base image or consumer, beyond the syntax directive and an inline `hadolint ignore`.
   Rationale lives in § Where the reasoning lives and the family README.
8. No project re-declares what the base already provides. See § What the base provides.
9. Compose files declare no `version:` key. Every long-running service has resource limits and a health signal. See §
   Compose.

## Syntax

Every Dockerfile begins with `# syntax=docker/dockerfile:1` as its literal first line, the base images here and the thin
consumer files in a project alike. It pins the stable BuildKit frontend so build-time mounts, secrets, and heredocs
parse identically on every machine and in CI. The directive is the one line that is not a build instruction and, in a
consumer Dockerfile, the one line that is not a comment-free instruction either.

## What the base provides

The PHP base (`gustavofreze/php`, four targets) bakes in everything below. A project Dockerfile that restates any of
these is wrong:

- Extensions: the official image set plus `bcmath`, `pdo_mysql`, and `zip`, with no leftover build dependencies.
- Non-root runtime: PHP-FPM runs as `www-data`, `WORKDIR /var/www/html` owned by it.
- Hardening: `php.ini-production` active and the development template deleted, `expose_php` and
  `display_errors` off, `allow_url_include` off, arguments stripped from exception traces, strict and transport-locked
  session cookies, and the process escape functions disabled.
- OPcache defaults: production tuning in `runtime`, development tuning in `development`.
- A container health check probing the FPM socket, and graceful shutdown through the official
  `STOPSIGNAL SIGQUIT` plus a 10s `process_control_timeout`.
- Development tooling (Xdebug, Composer, bash, git) in the `development` target only.
- A `cli` tooling variant (Composer, Xdebug coverage, CodeSniffer, Mess Detector)
  consumed by a project Makefile, never by a Dockerfile.

The Python base (`gustavofreze/python`, four targets) bakes in the `app` user (uid 1000) with
`WORKDIR /app`, the project-local virtual environment on `PATH` with `VIRTUAL_ENV` set, the container-correct
interpreter defaults (`PYTHONUNBUFFERED`, `PYTHONDONTWRITEBYTECODE`,
`PYTHONFAULTHANDLER`), and a pinned cacheless pip. Poetry and the C toolchain live in `builder` and
`cli`, Poetry and debugpy in `development`, and neither reaches `runtime`.

## Stage vocabulary and tags

Four stage names are the closed vocabulary of published targets. Each names what the image is, and a family ships only
the stages its role calls for. `scripts/discover-images.sh` enforces the list, so a Dockerfile is free to name any other
stage it needs, typically to pull a pinned upstream binary in through `COPY --from`, and that stage publishes no tag.
Naming such a stage is the right way in, because Dependabot's Docker parser matches `FROM` lines and would never see a
bare `COPY --from=<image>` pin.

- **`builder`**. The compilation base a project inherits via `FROM`. It carries the toolchain that installs dependencies
  and compiles them, and the multi-stage build discards it.
- **`runtime`**. The production image the platform runs.
- **`cli`**. Local command-line tooling for one-shot commands, invoked from a project Makefile.
- **`development`**. A variant of `runtime` built `FROM runtime`, adding local development tooling. It runs on a
  developer machine and is never deployed. It is subordinate to `runtime`, not a peer.

Every published tag is `<upstream-minor>-<role>-<semver>`, where `role` is identical to the stage name. There is no bare
tag: a role always sits between the upstream minor and the semantic version. Version tags are immutable, so any input
change bumps the build unit `VERSION`. `latest` is forbidden. Each stage also carries one floating alias
`<upstream-minor>-<role>` that the weekly security rebuild republishes. Be precise about what that rebuild can do:
because every `FROM` pins an exact patch and distro release, pulling that pin again returns the same bytes, so the
rebuild refreshes only the packages this repository installs itself through `apk add` and nothing in the inherited base
layers. What moves the base forward is Dependabot opening a pull request for the next upstream patch, which bumps the
build unit `VERSION` and republishes. A project takes either the versioned tag or the alias, and § Consuming is where
each one fits.

## Version layer

Each family keeps one build unit per upstream minor, under an `<upstream-minor>/` subdirectory (`images/php/8.5/`,
`images/python/3.14/`). The subdirectory segment is the exact minor read from the Dockerfile `FROM` pin. A build unit is
self-contained: its own `Dockerfile`, `VERSION`, configuration, baked scripts, `.dockerignore`, and `scripts/smoke`,
with a semantic version that advances independently of every other upstream version.

Two kinds of upstream change move differently:

- **Minor or major bump** (PHP 8.5 to 8.6). The Dockerfile and its configuration diverge, so the new version is a new
  sibling subdirectory that starts its own `VERSION` at `1.0.0`. The two lines publish in parallel and coexist, and each
  project migrates on its own schedule. Nothing in the old subdirectory changes.
- **Patch bump** (PHP 8.5.9 to 8.5.10). The upstream pin and the `VERSION` both move inside the same subdirectory. No
  new directory appears, and the floating alias tracks the new patch.

To add an upstream version, copy the current subdirectory to a new `<upstream-minor>/` beside it, repoint its Dockerfile
`FROM` to the new upstream pin (honoring the 7-day cooldown), reset its
`VERSION` to `1.0.0`, adjust the configuration the new upstream requires, and wire its build, lint, scan, audit,
efficiency, smoke, and publish steps into the Makefile beside the existing version.

## Dependency policy

NEVER pin an upstream image tag or a tool release published less than 7 days ago. Verify the publication date before
adopting one. This covers the base image and every pinned tool alike (Composer, Xdebug, CodeSniffer, Mess Detector, pip,
Poetry, debugpy).

Alpine package versions are the one deliberate exception to exact pinning: the Alpine repository is rolling and drops
old versions, so a pinned `apk` version breaks reproducibility instead of improving it. The exact upstream image tag
(patch version and distro release) is the reproducibility boundary, which is why DL3018 is relaxed in `.hadolint.yaml`
and nothing else is.

## Vulnerability acceptance

A finding that cannot be fixed locally is answered in two separate places, because two separate questions are being
asked. Mixing them is what produces an ignore list nobody can audit later.

- **Is the image affected?** That analysis lives in the family VEX document at `vex/<family>.openvex.json`, in OpenVEX
  form. Each statement names the vulnerability, the product, and a status: `not_affected` with an OpenVEX justification
  and an impact statement recording how absence or unreachability was verified inside the image, or `affected` with an
  action statement when the product genuinely carries it and no fix exists upstream. Both scanners read the document
  through `--vex`, and the CD workflow attaches it to every published image with `cosign attest --type openvex`, so a
  consumer scanning the image gets the same analysis instead of re-deriving it.
- **Does the gate block on it?** That policy lives in `.grype/<family>.yaml` and `.trivy/<family>.yaml`, and each holds
  exactly one kind of entry: a risk that is real, has no available remediation, and that the gate deliberately does not
  stop on. Both scanners report these despite `--only-fixed` and `--ignore-unfixed`, because the advisory names a fix in
  a release that no image this repository can pin has shipped yet. Every entry carries the date it was accepted and the
  condition that retires it. Nothing truthfully not affected belongs here, because the VEX already suppresses it in both
  scanners on its own.

A finding needs an entry in each scanner's file, and the two are not copies of each other. Trivy names a Go standard
library finding by CVE and Grype by GO advisory, and for the identical binary they disagree on both the count and the
severity. Write each file from what that scanner actually reported, and suppress only what its own threshold stops on:
an advisory Grype grades Medium passes `--fail-on high` unaided, so listing it would suppress more than the decision
being made. Only the Trivy format carries an `expired_at`, so a Trivy entry lapses on its own and a Grype entry does
not, which is why the Grype file says so in its own header.

Every one of these documents is per family and the Makefile passes each only to the family it was written for, so a
family with none of them scans bare. They sit under `.grype/` and `.trivy/` rather than at the repository root for that
reason: a root `.grype.yaml` or `.trivyignore` is picked up by every invocation of that scanner, which turns a single
family's accepted risk into a repository-wide exemption and into a silent one for anyone running the scanner by hand.

A VEX statement is a public claim, published with the image and signed, so it is written from what was verified inside
that image and never from what would be convenient for the gate. A vendored third-party binary is where that discipline
is hardest and matters most: its internals are not this repository's to reason about, so it gets `affected` with an
action statement, never a `not_affected` backed by a reachability argument nobody here can check.

## Hermetic builds

A build reads its inputs from the build context and from pinned, verified sources. Nothing else.

- Configuration files are `COPY`ed from the build unit's `conf/` directory. Downloading a `.ini` from a branch URL at
  build time makes the image depend on the state of a remote branch, produces a different image from the same source on
  a different day, and offers no integrity check. It is forbidden.
- A remote artifact (a phar, a release tarball) is fetched to a scratch path with an exact version in the URL, verified
  against a sha256 recorded as an `ARG` in the Dockerfile, and only then installed onto `PATH`. An unverified artifact
  is never executable inside the image, not even between two instructions.
- `ADD` is never used. It also fetches URLs and unpacks archives, which hides what enters the image.
- A package manager invoked at build time pins its whole resolved tree, not just the packages named on the command line.
  Pinning only the named ones leaves every transitive dependency floating to whatever the index serves that minute, and
  the failure is invisible until two builds of the same commit disagree. Python does this with a pair beside the
  Dockerfile: `requirements.txt` names what the image installs, `constraints.txt` pins the tree those resolve to, and
  both are bound in with `RUN --mount=type=bind` so they shape the install without entering a layer. Regenerate the
  constraints from the pinned base whenever a version in the requirements moves. A constraint is not a requirement, so
  the second file changes no image's contents on its own: a package nothing pulls stays absent.
- A pinned version lives in exactly one file, and that file is one an updater reads. A version in a Dockerfile `ARG` is
  read by nobody: the Docker ecosystem parses `FROM` lines and stops there, so an `ARG PIP_VERSION` ages silently no
  matter how many updaters the repository configures. Naming the tools in a manifest of their own ecosystem, and wiring
  that ecosystem into `dependabot.yml`, is what turns a pin into something that moves.

## Lean layers

Every layer carries only what the image keeps. One `RUN` groups a single concern and cleans up after itself in the same
layer, so nothing it fetched survives into the image:

- Package installs use the no-cache mode of the package manager, and build-only dependencies are installed under a
  virtual group and deleted (`apk add --virtual .build-deps … && … && apk del
  .build-deps`) before the `RUN` ends. A tool removed in a later layer still occupies the earlier one, so the removal
  and the install share a layer. The `builder` target is the deliberate exception: it keeps the toolchain, because
  carrying it is the whole point of that target.
- `COPY` moves files in, never `ADD`.
- Dependency layers come before code layers so a code change does not invalidate the dependency cache.

The efficiency stage of the review gate holds these to the thresholds in `.dive-ci`. A widening layer is a signal to
prune the `RUN`, not to relax the threshold.

## Authoring

Every image family lives under `images/`, one directory per family, each holding one self-contained build unit per
upstream minor under an `<upstream-minor>/` subdirectory. Each build unit ships a single `Dockerfile` with the targets
it needs, a `VERSION` file, its configuration or baked scripts, a `.dockerignore`, and a `scripts/smoke` assertion
script. A family `README.md` sits one level up as the umbrella.

Every base Dockerfile matches its siblings on all of these:

1. The literal first line is `# syntax=docker/dockerfile:1`.
2. No comment anywhere else. The only other `#` line permitted is an inline `hadolint ignore=<rule>`
   directive, which is a lint instruction and not a comment. See § Where the reasoning lives.
3. A full OCI label set (`url`, `title`, `source`, `vendor`, `authors`, `licenses`, `description`,
   `documentation`) on each target built from a distinct upstream base, and a `title` and
   `description` override on each derived target. Entries are ordered by key length ascending, ties alphabetically, the
   same ordering the shell scripts here use for their constants.
4. Targets ordered base to derivative, never a derivative before the stage it builds on.
5. A uniform package pattern: no-cache installs, build-only dependencies in a virtual group deleted in the same `RUN`,
   one `RUN` per concern chained with `&&`.
6. A non-root last `USER` on every target an application runs, with `WORKDIR` owned by that user and only unprivileged
   ports exposed. A target that legitimately stays root is the documented, justified exception, carries an inline
   `hadolint ignore=DL3002` on the `USER root` line, and is audited with the matching CIS exemption named in the
   Makefile.
7. A `HEALTHCHECK` on every target that starts a long-running process of its own, and none on the targets with nothing
   to probe (a builder base, a language runtime, a one-shot tooling image). A target with no health check is audited
   with the CIS-DI-0006 exemption, named in the Makefile.
8. Baked drop-in configuration is namespaced and numbered (`zz-gustavofreze-<NN>-*` in a `conf.d`), so it layers over
   the upstream defaults in a predictable order and a derived target can replace a single drop-in by reusing its file
   name.
9. A baked executable script lives at one canonical path, `/usr/local/bin/<name>`, copied with
   `COPY --chmod=755`, carrying a shebang as its first line, and sourced from the family's `bin/`. Every reference to it
   uses that same path.

## Where the reasoning lives

Dockerfiles here carry no prose. The rationale for a non-obvious instruction lives in this section and in the family
README, so it is written once instead of drifting between a comment and a document. Read this before reordering or
simplifying an instruction: each item below is load bearing, and the build or the gate breaks when it is undone.

- **The PHP `development` drop-ins are `COPY`ed before the `pecl install` that follows them.** The runtime's hardening
  drop-in disables the process functions, and PEAR calls `exec()` while building an extension, so the install fails with
  a fatal in `OS/Guess.php` if the ordering is swapped for cache reasons. `conf/development.ini` clears
  `disable_functions`, which is what makes it work.
- **The `development` OPcache drop-in reuses the runtime's file name.** That replaces the production tuning instead of
  stacking a second `[opcache]` section on top of it. Renaming it silently keeps production tuning active in the
  development image.
- **Drop-ins are numbered because PHP reads `conf.d` alphabetically.** Hardening is `10`, the development and cli
  overrides are `90`. An override numbered below the hardening file loses.
- **`conf/fpm-shutdown.conf` opens `[global]` and then reopens `[www]`.** The alphabetical
  `php-fpm.d` include order reaches it with the `[www]` pool of `zz-docker.conf` still open, and
  `conf/fpm-development.conf` relies on that pool still being open when it is read.
- **The Python `runtime` uninstalls pip on purpose.** It is the largest dependency tree in the image and nothing in it
  is reachable from an application running the virtual environment the builder populated. The `ensurepip` wheel stays as
  the way back. `scan-python` runs Trivy against this target with no VEX at all, and every statement the VEX would have
  suppressed covers a package pip vendors, so restoring pip here fails the gate.
- **The Python `builder` keeps its C toolchain on purpose.** It is the stage an application compiles wheels in, so
  pruning it only moves the same install into the consuming Dockerfile.
- **The `cli` targets end as root on purpose.** They are invoked over a bind mount owned by the caller and must write
  into it. That is why each carries `hadolint ignore=DL3002` and is audited with the CIS-DI-0001 exemption.
- **Each phar is fetched to a scratch path and installed onto `PATH` only after `sha256sum -c`
  passes,** so an unverified artifact is never executable, not even between two instructions.
- **`phpmd` on `PATH` is a wrapper, not the phar.** The phar sits at `/usr/local/lib/phpmd.phar` and the wrapper
  silences the deprecation notices PHPMD 2.15.0 raises on PHP 8.5, keeping stdout parseable.
- **The last `USER` is a numeric uid, not a name.** `USER 82` (php `www-data`) and `USER 1000` (python
  `app`). A name only resolves through the image's own `/etc/passwd`, so an orchestrator cannot verify
  it: Kubernetes `runAsNonRoot` rejects a pod whose image declares a non-numeric user and no explicit
  `runAsUser`. hadolint enforces this as DL3066. The named user still exists in the image, so `whoami`
  and `COPY --chown=www-data:www-data` keep working.
- **The docker CLI ships in the PHP `cli` target and nowhere else.** It is there for one reason: a PHP
  integration suite that drives throwaway containers (a database, a migration runner) shells out to
  `docker` against the host socket, and the suite cannot bootstrap without the binary. That is a
  tooling-image concern, so it stays in the one image a Makefile invokes and never reaches a `builder`,
  a `runtime`, or any Python target, each of which asserts its absence in `scripts/smoke`. The PHP
  `cli` smoke asserts the opposite, so removing it breaks that suite loudly instead of silently. The
  cost is roughly 30MB. It is copied from the pinned official image
  (`COPY --from=docker:<version>-cli-alpine<release>`) rather than installed with `apk add docker-cli`,
  and that is not a style choice: Alpine 3.24 packages a build linked against an older Go toolchain,
  which Grype reports as a HIGH in `crypto/x509` (GO-2026-5037). The official image tracks Go closely
  enough to be clean. Read the toolchain out of a candidate before pinning it
  (`grep -aoE 'go1\.[0-9]+\.[0-9]+' /usr/local/bin/docker`), because the Go version, not the Docker
  version, is what the scanners judge. It enters through a named stage rather than a bare
  `COPY --from=<image>`, because Dependabot's Docker parser matches `FROM` lines and nothing else, so a
  bare reference would be a pin carrying Go advisories that no updater watches. A caller still has to
  mount the host socket itself, which is root-equivalent on the host.
- **The gate runs two vulnerability scanners.** Trivy reads the distro security database, Grype
  cross-references upstream advisories and Go module data. Neither is a superset: Grype caught a HIGH
  in the Go stdlib of a vendored binary that Trivy reported clean on the same image. An accepted
  finding is written once in the family VEX document and read by both, per § Vulnerability acceptance.
- **`${PHPIZE_DEPS}` is deliberately unquoted.** It is a space-separated package list that must word split, which is why
  SC2086 is relaxed in `.hadolint.yaml`.

Every change runs the review gate (`make review`: lint, build, scan, audit, efficiency, smoke) before publication, and
any input change bumps `VERSION`. A vulnerability finding that cannot be fixed locally is accepted only the way
§ Vulnerability acceptance describes, scoped to the single family it affects and never repository-wide.

## Smoke contract

`scripts/smoke` boots a throwaway container per target and asserts what that target's class promises. It sources the
shared host-side helper library (`scripts/smoke-lib.sh`, resolved through the
`SMOKE_LIB` path the Makefile exports) and adds only the family-specific assertions.

- **Service target**: runs as a non-root user, its baked health check drives the container to a healthy state, no build
  tooling or development tooling survives into the production surface, the hardening is active, and the pinned versions
  are present.
- **Builder target**: its toolchain versions are pinned and present, it runs non-root, and its working directory is the
  expected application root.
- **One-shot or CLI target**: its pinned tools answer `--version`, and its working directory is the expected application
  root.

A target that quietly reverted to root, lost its hardening, or drifted off a pinned version fails its own smoke.

## Build context

Every Dockerfile has a `.dockerignore` beside it covering at least `.git`, IDE directories, the
`Dockerfile` and `.dockerignore` themselves, `*.md`, `VERSION`, and `scripts/`. In a project, add
`.env` and `.env.local`. Secrets never enter a build context copy.

## Secrets

No secret is embedded in any image layer or versioned compose file. Build-time credentials enter through a BuildKit
secret (`RUN --mount=type=secret,id=<name>`) and the caller passes
`--secret id=<name>,env=<VAR>`. Runtime configuration enters through environment variables, never through files baked
into the image.

## Consuming

A project consumes the base in two thin files:

- `Dockerfile.dev`: `FROM gustavofreze/<family>:<minor>-development-<V>` plus a `COPY` of the code.
- `Dockerfile.prod`: a builder stage `FROM gustavofreze/<family>:<minor>-builder-<V>` installing dependencies, then a
  runtime stage `FROM gustavofreze/<family>:<minor>-runtime-<V>` copying the built tree with the runtime user's
  ownership.

A project adds only its own dependencies, code, and tuning. Dependency layers come before code layers so the cache
survives code changes.

Both tag forms are published and a consumer picks one. The versioned tag is reproducible and moves only on a bump,
which is why `Dockerfile.prod` and anything else that ships names it. The floating `<upstream-minor>-<role>` alias
picks up the weekly security rebuild with no pull request and gives up reproducibility for it, a fair trade for the
`cli` tooling and for a local `Dockerfile.dev`. An alias never crosses an upstream minor, and it moves only when the
client re-pulls, so `--pull=always` is what makes it float.

A consumer Dockerfile carries no comment, like the base images it inherits. The only line that is not a build
instruction is the `# syntax=docker/dockerfile:1` directive. The reasoning behind each step lives in the base image it
inherits and in this rule, never copied into the project.

The `cli` image needs no Dockerfile at all. It is referenced by a project Makefile variable and invoked over a bind
mount.

## Compose

`docker-compose.yml` at the repository root is the one compose file here and it declares no runnable
service: it is the version manifest for the gate's validator images, read by the Makefile and updated
by Dependabot's `docker-compose` ecosystem. Sitting at the root is what makes `docker compose` find it
by default, which is also why its own header warns that bringing it up is not a thing anyone should
do. The service rules below do not apply to it, because nothing in it is ever brought up. They apply
to a compose file in a consuming project.

No `version:` key (deprecated). Every long-running service declares `cpus` and `mem_limit`. Services whose image ships a
`HEALTHCHECK` inherit it, other long-running services declare a `healthcheck:`
block. One-shot jobs are exempt. Databases persist on named volumes prefixed with the service name. Secrets reach
containers through `env_file:` entries pointing at gitignored files, never through values committed in the compose file.
