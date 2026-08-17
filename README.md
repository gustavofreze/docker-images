# Docker images

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

* [Overview](#overview)
    - [Layout](#layout)
* [Installation](#installation)
    - [Repository](#repository)
    - [Build](#build)
    - [Review](#review)
* [Images](#images)
    - [Targets](#targets)
    - [Tags](#tags)
    - [Versioning](#versioning)
    - [Publication](#publication)
    - [Usage contract](#usage-contract)
    - [Self-verification](#self-verification)
    - [Adding a family](#adding-a-family)
    - [Adding an upstream version](#adding-an-upstream-version)
* [License](#license)

<div id='overview'></div>

## Overview

Hardened, reproducible container base images for PHP and Python projects. Each family ships one self-contained build
unit per upstream version: a multi-target `Dockerfile`, its baked configuration or scripts, a `VERSION` file, and a
`scripts/smoke` assertion script. A single verification gate (`make review`) lints, builds, scans, audits, checks layer
efficiency, and smoke-tests every family before a tag is published. Every validator runs in a container, so nothing
beyond Docker and GNU Make is installed on the host.

The premises the images are held to:

- **Exact upstream pins.** Every `FROM` names a patch version and a distro release, never a moving tag. An upstream tag
  published less than 7 days ago is never adopted. A package manager run at build time pins its whole resolved tree, not
  only the packages named on the command line, so the same commit builds the same image on any day and any runner.
- **Hermetic builds.** No configuration or tool is fetched from the network at build time without a pinned version and a
  verified sha256. Configuration is copied from the build context.
- **Non-root by default.** Every target an application runs drops to an unprivileged user. A target that keeps root is a
  named, justified exception that starts no long-running process.
- **Lean layers.** One `RUN` per concern, build-only dependencies installed under a virtual group and deleted before the
  layer closes, `COPY` never `ADD`.
- **Immutable versioned tags.** Any change to a Dockerfile or its inputs bumps the build unit's
  `VERSION`. `latest` is forbidden.
- **A gate before publication.** Publishing an unreviewed image is not possible through the Makefile or the CD workflow.

Each family's own README is the reference for that family: its published tags, what the images bake in, and how to
consume them. This README covers only what is shared across families: the tag scheme, the versioning rules, the gate,
and the usage contract.

<div id='layout'></div>

### Layout

Every family lives under `images/`, one directory per family. A family holds one self-contained build unit per upstream
version under an `<upstream-minor>/` subdirectory, plus a family `README.md` one level up as the umbrella. A root
`scripts/` holds the shared host-side smoke library every family sources and the discovery script the workflows build
their matrix from.

```
docker-images/
├── Makefile                        # build, review, publish
├── docker-compose.yml              # validator image versions, single source, Dependabot tracked
├── vex/                            # per-CVE analysis, published with the images as an attestation
│   ├── php.openvex.json
│   └── python.openvex.json
├── .grype/                         # gate policy for Grype: risks with no remediation, per family
│   ├── php.yaml
│   └── python.yaml
├── .trivy/                         # the same acceptance for Trivy, which names them differently
│   └── php.yaml
├── scripts/
│   ├── smoke-lib.sh                # shared host-side smoke helpers every family sources
│   └── discover-images.sh          # build matrix: one entry per target, read from the Dockerfiles
└── images/
    ├── php/
    │   ├── README.md               # family umbrella: role, versions, targets, consumption
    │   └── 8.5/                    # build unit for the 8.5 upstream line
    │       ├── Dockerfile          # multi-target: builder, cli, runtime, development
    │       ├── VERSION             # base semantic version for this line
    │       ├── .dockerignore
    │       ├── bin/                # binaries baked into the images (FPM health check)
    │       ├── conf/               # PHP, OPcache, Xdebug, and FPM configuration
    │       └── scripts/smoke       # boots throwaway containers, asserts the runtime contract
    └── python/
        ├── README.md
        └── 3.14/                   # build unit for the 3.14 upstream line
            ├── Dockerfile          # multi-target: builder, cli, runtime, development
            ├── VERSION
            ├── .dockerignore
            ├── requirements.txt    # the tools the image installs, tracked by Dependabot
            ├── requirements-development.txt
            ├── constraints.txt     # the tree they resolve to, so a build is reproducible
            └── scripts/smoke
```

<div id='installation'></div>

## Installation

<div id='repository'></div>

### Repository

To clone the repository using the command line, run:

```bash
git clone https://github.com/gustavofreze/docker-images.git
```

<div id='build'></div>

### Build

To build every image family locally, run:

```bash
make build
```

Build a single family with `make build-<family>` (`build-php`, `build-python`). No registry is involved locally.
`make discover` prints every build unit and the tags it publishes.

<div id='review'></div>

### Review

To run the full local gate (lint, build, scan, audit, efficiency, smoke), run:

```bash
make review
```

Scope the same gate to one family with `make review-<family>`. `make verify` is an alias of
`make review`. You can check other available commands by running `make help`.

<div id='images'></div>

## Images

| Family | Role                                                 | Versions | Docker Hub                                                          | GitHub Packages                                                                                    | Detail                            |
|:-------|:-----------------------------------------------------|:---------|:--------------------------------------------------------------------|:---------------------------------------------------------------------------------------------------|:----------------------------------|
| PHP    | PHP-FPM runtime plus build, development, and cli     | 8.5      | [gustavofreze/php](https://hub.docker.com/r/gustavofreze/php)       | [ghcr.io/gustavofreze/php](https://github.com/gustavofreze/docker-images/pkgs/container/php)       | [README](images/php/README.md)    |
| Python | Interpreter runtime plus build, development, and cli | 3.14     | [gustavofreze/python](https://hub.docker.com/r/gustavofreze/python) | [ghcr.io/gustavofreze/python](https://github.com/gustavofreze/docker-images/pkgs/container/python) | [README](images/python/README.md) |

<div id='targets'></div>

### Targets

Four stage names are the closed vocabulary. Each names what the image is, and a family ships only the stages its role
calls for.

| Target        | What it is                                                                          | Families    |
|:--------------|:------------------------------------------------------------------------------------|:------------|
| `builder`     | Compilation base a project inherits via `FROM`, discarded in the multi-stage build. | php, python |
| `runtime`     | Production image the platform runs.                                                 | php, python |
| `cli`         | Local command-line tooling for one-shot commands, invoked from a project Makefile.  | php, python |
| `development` | Variant of `runtime` built `FROM runtime`, adding local development tooling.        | php, python |

`development` is subordinate to `runtime`, not a peer of it. It runs on a developer machine and is never deployed. Every
target except `cli` runs as a non-root last user. The `cli` tooling images keep root as a named, justified exception,
because they are invoked over a bind mount owned by the caller and must be able to write into it. A `HEALTHCHECK` ships
only on a target that starts a long-running process of its own. Which targets those are, and what each family bakes into
them, is documented in that family's README.

<div id='tags'></div>

### Tags

Every published tag is `<upstream-minor>-<role>-<semver>`, where `role` is identical to the stage name:

```
gustavofreze/<family>:<upstream-minor>-<role>-<V>
```

- There is no bare tag. A role always sits between the upstream minor and the base version.
- Version tags are immutable. Any change to a Dockerfile or its inputs bumps `<V>`, and the CI gate fails a pull request
  that touches a build unit without bumping its `VERSION`.
- `latest` is forbidden.
- Each stage also carries one floating alias `<upstream-minor>-<role>` (`8.5-runtime`, `3.14-builder`, and the rest).
  The weekly rebuild repoints these aliases. Pin the full versioned tag in a project, and use the alias only for a local
  experiment.

Be precise about what that weekly rebuild can and cannot do. Because every `FROM` pins an exact patch and distro
release, and the official images publish a new tag rather than rewriting an old one, pulling that pin again always
returns the same bytes. The rebuild therefore refreshes only the handful of packages this repository installs itself
through `apk add`, which carry no version pin, and nothing in the inherited base layers or in the PHP and CPython
binaries. What actually moves the base forward is Dependabot opening a pull request for the next upstream patch, which
then bumps the build unit `VERSION` and republishes. The rebuild's second job is detection: it scans the published
versioned tags every week and opens an issue only when a finding has a fix available, so a report means there is
something to do.

<div id='versioning'></div>

### Versioning

Each family keeps one build unit per upstream minor, under an `<upstream-minor>/` subdirectory (`images/php/8.5/`,
`images/python/3.14/`). A build unit is self-contained: its own `Dockerfile`, `VERSION`, configuration, baked scripts,
and `scripts/smoke`, with a base semantic version `<V>` that advances independently of every other upstream version. PHP
8.5 can sit at `1.3.0` while a future PHP 8.6 sits at `1.0.0`.

Two kinds of upstream change move differently:

- **Minor or major bump** (PHP 8.5 to 8.6, Python 3.14 to 3.15). The Dockerfile and its configuration diverge, so the
  new version is a new sibling subdirectory starting its own `VERSION` at `1.0.0`. The two lines publish in parallel and
  coexist, and each project migrates on its own schedule.
- **Patch bump** (PHP 8.5.9 to 8.5.10). The upstream pin and the build unit's `VERSION` both move inside the same
  subdirectory, no new directory.

Upstream pins follow a dependency cooldown: never adopt an upstream tag published less than 7 days ago. This applies to
the base image and to every pinned tool (Composer, Xdebug, CodeSniffer, Mess Detector, pip, Poetry, debugpy).

<div id='publication'></div>

### Publication

Locally, `make publish` pushes the versioned tags, and each `publish-<family>` target lists `review-<family>` as a make
prerequisite, so the push only happens after lint, build, scan, audit, efficiency, and smoke all passed for the family
being published. `REGISTRY` defaults to `docker.io` and accepts any other registry (`make publish REGISTRY=ghcr.io`).

In CI, the `CD` workflow runs the same gate before it publishes, on a native `linux/amd64` runner and a native
`linux/arm64` one, so every architecture that ships was actually built, scanned, audited, and smoke-tested rather than
only cross-built. It then pushes the immutable versioned tag and the floating alias to Docker Hub and to the GitHub
container registry.

Version tags are meant to be stable, and the pull request version guard is what holds that: it fails a pull request that
touches a build unit without bumping its `VERSION`. The publishing job itself does not check the registry, so a push
straight to `main` republishes whatever tag the build units name, overwriting a tag that is already out there. Route
changes through a pull request and the guard catches the missing bump before it reaches the registry.

A family that carries a finding it cannot fix locally publishes an OpenVEX analysis as a cosign attestation next to
every image, versioned at `vex/<family>.openvex.json`. It states per CVE whether the image is genuinely affected, and
`affected` statements are reported rather than silenced: the risk is disclosed, not hidden. Whether the local gate stops
on one is a separate decision, recorded in `.grype/<family>.yaml` and `.trivy/<family>.yaml` with the date it was
accepted and the condition that retires it, and never mixed into the analysis. Both files are needed because the two
scanners name the same finding differently, by GO advisory and by CVE. How to pass the document to a scanner is in each
family's README, [PHP](images/php/README.md) and [Python](images/python/README.md).

<div id='usage-contract'></div>

### Usage contract

A project consumes a base image and adds only its own dependencies, code, and tuning. The concrete snippet for each
family lives in that family's README. The rules that hold across every family:

1. Pin the full versioned tag. Never a floating alias, never `latest`.
2. Do not re-declare what the base provides: extensions, the non-root user, hardening, OPcache defaults, the virtual
   environment path, the health check, the interpreter defaults.
3. Ship a `.dockerignore` next to each Dockerfile, and never copy a secret into a build context.
4. Build-time credentials enter through a BuildKit secret (`RUN --mount=type=secret,id=<name>`), never through a baked
   `ARG` or `ENV`.
5. Dependency layers come before code layers, so a code change does not invalidate the dependency cache.

<div id='self-verification'></div>

### Self-verification

`make review` runs the full local gate in order:

1. **Lint** every Dockerfile with hadolint, with the shell inside each `RUN` checked by ShellCheck, and every standalone
   shell script with ShellCheck directly at its strictest setting.
2. **Build** all targets.
3. **Scan** them with Trivy for fixable HIGH and CRITICAL vulnerabilities.
4. **Audit** each image with Dockle against the CIS Docker Benchmark, per target: the non-root last-user check stays
   active on every target but the two named `cli` exceptions, and the health check requirement stays active on every
   target that runs a process of its own. It also checks for orphan setuid and setgid bits, credentials in the
   environment, `COPY` over `ADD`, and a clean package cache.
5. **Efficiency** check of the layers with dive against the thresholds in `.dive-ci` (no unpruned build dependency, no
   forgotten cache).
6. **Smoke** the runtime contract in throwaway containers (non-root, extensions, hardening, OPcache mode, health check,
   pinned tool versions, development tooling present only where it belongs).

Every stage runs in a container: nothing beyond Docker and make is installed on the host. Each validator version is
written once, in `docker-compose.yml`, which the Makefile reads and Dependabot tracks, so no tool tag can quietly fall
behind.
`make review-<family>` scopes the whole gate to a single family. Baseline suppressions and thresholds are documented,
each with a justification and a date: the lint relaxations in `.hadolint.yaml`, the layer-efficiency thresholds in
`.dive-ci`, and the per-target CIS exemptions in the Makefile beside the audit runner they apply to.

<div id='adding-a-family'></div>

### Adding a family

Create the build unit under `images/<family>/<upstream-minor>/` mirroring `images/php/8.5/`: a multi-target
`Dockerfile`, `VERSION`, `.dockerignore`, `conf/` or `bin/` where the family needs them, and a `scripts/smoke` asserting
the contract. Add a family `README.md` one level up. Then wire the family into the Makefile aggregates (`lint-`,
`build-`, `scan-`, `audit-`, `efficiency-`, `smoke-`, `publish-`, and `review-<family>`) and run `make review-<family>`
until it passes. The workflows pick the new targets up automatically, because their matrix comes from
`scripts/discover-images.sh`.

<div id='adding-an-upstream-version'></div>

### Adding an upstream version

When a family's upstream moves to a new minor, copy the current build unit to a new
`<upstream-minor>/` beside it (for example `images/php/8.5/` to `images/php/8.6/`), repoint its Dockerfile `FROM` to the
new upstream pin (honoring the 7-day cooldown), reset its `VERSION` to `1.0.0`, and adjust the configuration the new
upstream requires. Wire the new version's build, lint, scan, audit, efficiency, smoke, and publish steps into the
Makefile beside the existing version, list it in the family `README.md`, and run `make review-<family>` until it passes.
The old version stays untouched, both lines publish in parallel, and each project migrates on its own schedule.

<div id='license'></div>

## License

Collection is licensed under [MIT](LICENSE).
