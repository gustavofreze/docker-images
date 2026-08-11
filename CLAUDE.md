# Project

Public container base images for PHP and Python projects, published to Docker Hub and to the GitHub
container registry. This repository is the single source for what is replicable across projects: base
images, their configuration, and the verification gate. Nothing here is project-specific and no
application code ever enters an image.

## Commands

Everything runs through the `Makefile`. Run `make help` for the full list.

- `make build`. Build every image family (PHP and Python, each with `builder`, `runtime`,
  `development`, and `cli` targets).
- `make review`. The full local gate, in order: lint every Dockerfile, build, scan for HIGH and
  CRITICAL vulnerabilities, audit each image against the CIS Docker Benchmark, check layer
  efficiency, and smoke-test the runtime contract. Run it before publishing.
  `make review-<family>` scopes the same gate to one family, `make verify` is an alias.
- `make publish REGISTRY=<registry>`. Push the immutable versioned tags. `REGISTRY` defaults to
  `docker.io`.
- `make discover`. List every build unit and the tags it publishes.

Every validator runs in a container: nothing beyond Docker and make is installed on the host.

## Structure

Every image family lives under `images/`, one directory per family (`php/`, `python/`). Each family
holds one self-contained build unit per upstream minor under an `<upstream-minor>/` subdirectory
(`images/php/8.5/`, `images/python/3.14/`), shipping a multi-target `Dockerfile`, a `VERSION` file,
its configuration or baked scripts, a `.dockerignore`, and a `scripts/smoke` assertion script. A root
`scripts/` holds the shared host-side smoke library every family sources and the discovery script the
CI and CD workflows build their matrix from. The README documents the versioning scheme, the
publication method, and the usage contract.

## Dependency policy

NEVER pin an upstream image tag or a tool release published less than 7 days ago. Verify the
publication date before adopting one. Any change to a Dockerfile or its inputs bumps that build
unit's `VERSION`, and version tags are immutable. The CI version guard fails a pull request that
touches a build unit without bumping it.

## Conventions

Rules (`.claude/rules/*.md`) are persistent invariants auto-injected when you read a file matching
their `paths:` glob. The `docker-images` rule is normative for authoring here. Repository
documentation (README, commit messages) is written strictly in English.

- **Prose punctuation.** Do not use `;`, ` — ` (em-dash), ` – ` (en-dash), or ` -- ` as clause
  separators in prose or Markdown. Use two sentences, a comma, a colon, or parentheses instead.
  Hyphens in compound identifiers and Markdown tables are exempt.
