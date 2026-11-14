# Contributing

* [Overview](#overview)
* [How can I contribute?](#contributing)
    - [Reporting bugs](#reporting-bugs)
    - [Suggesting improvements](#suggesting-improvements)
    - [Developing](#developing)
* [How the repository works](#how-the-repository-works)
    - [Ground rules](#ground-rules)
    - [Versioning](#versioning)
    - [Changing an image](#changing-an-image)
    - [Adding an upstream version](#adding-an-upstream-version)
    - [Adding a family](#adding-a-family)
    - [Handling a vulnerability](#handling-a-vulnerability)
    - [Publication](#publication)

<div id='overview'></div>

## Overview

Thank you for investing your time in contributing to the project.

These are the main guidelines, use your common sense, and feel free to propose changes to this document in a pull
request.

<div id='contributing'></div>

## How can I contribute?

This section guides you through possible ways to contribute.

<div id='reporting-bugs'></div>

### Reporting bugs

Bugs are tracked as [issues](https://github.com/gustavofreze/docker-images/issues) on GitHub. Create an issue and
provide the following information:

- Use a clear and descriptive title to identify the problem.
- Describe the exact steps that reproduce the problem in as much detail as possible. When listing the steps, don't say
  just what you did, but explain how you did it.
- Tell which image tag you are using, and on which architecture.

A CVE in an upstream package that a scanner already reports is a regular issue: name the image tag and the identifier.
A vulnerability in this repository, or in how an image is built, is not. Report it privately through
[GitHub security advisories](https://github.com/gustavofreze/docker-images/security/advisories/new).

<div id='suggesting-improvements'></div>

### Suggesting improvements

Improvement suggestions are tracked as [issues](https://github.com/gustavofreze/docker-images/issues) on GitHub.
Create an issue and provide the following information:

- Use a clear and descriptive title to identify the suggestion.
- Describe the current behavior, and explain what behavior you expected to see and why.
- Explain why this enhancement would be useful for most users.
- Tell which image tag you are using.

<div id='developing'></div>

### Developing

To start development, you will need Docker with BuildKit and GNU Make. Nothing else is installed on the host: every
linter, scanner, and auditor runs in a container, at the version `docker-compose.yml` names. Then follow these steps:

- Fork the repository.

- Make a clone of the repository from your fork.

- Create a new branch from the **main** branch. To give greater readability, use one of the prefixes, according to the
  type of change, **fix**/xpto, **feature**/xpto, **docs**/xpto, **chore**/xpto.

- Make the change inside one build unit, `images/<family>/<upstream-minor>/`, following the
  [ground rules](#ground-rules).

- Bump the build unit you changed. It moves the `VERSION` and every tag and pin the family README names:

  ```bash
  ./scripts/bump-build-unit.sh images/<family>/<upstream-minor>
  ```

- Run the full gate for the family you changed, until it passes:

  ```bash
  make review-<family>
  ```

- Make the commits with a subject that is one sentence, with the verb in the imperative, ending with a period.
    - e.g (Upgrade the inherited openssl and stop reporting accepted risk.)

- Open a pull request from your branch to the **main** branch. In the description, state what was verified and what
  was not. Two checks run, and both must pass:

    - **Version guard**: every build unit the pull request touches bumped its `VERSION`.
    - **Review**: `make review-<family>` passes for every family, on native `linux/amd64` and `linux/arm64` runners.

- With the code review approved, the pull request is squash-merged into the **main** branch, and the merge is what
  publishes the images. There is no release branch and no tag to create.

A scanner database moves on its own, so the gate can turn red on a tree nobody touched. When that happens the fix
belongs in the same pull request, see [Handling a vulnerability](#handling-a-vulnerability).

<div id='how-the-repository-works'></div>

## How the repository works

What a change has to respect, and what happens to it after the merge.

<div id='ground-rules'></div>

### Ground rules

The normative text is [`.claude/rules/docker-images.md`](.claude/rules/docker-images.md) for an image and
[`.claude/rules/shell-scripts.md`](.claude/rules/shell-scripts.md) for every Bash file and every `RUN` body. The lint
stage enforces both. The short version:

- **Exact pins.** Every `FROM` names a patch version and a distro release. A package manager run at build time pins
  its whole resolved tree, not only the packages named on the command line.
- **Hermetic builds.** Nothing is fetched at build time without a pinned version and a verified sha256. Configuration
  is copied from the build context.
- **Non-root by default.** Every target an application runs drops to an unprivileged user. A target that keeps root is
  a named, justified exception.
- **Lean layers.** One `RUN` per concern, build-only dependencies installed under a virtual group and deleted before
  the layer closes, `COPY` never `ADD`.
- **No comments in a Dockerfile.** Only the syntax directive and an inline `hadolint ignore`. The reasoning behind a
  non-obvious instruction lives in the rule, under "Where the reasoning lives", so it is written once.
- **Four target names.** `builder`, `runtime`, `development`, and `cli` are the closed vocabulary, and `development`
  is built `FROM runtime`.
- **English only**, in documentation, commit messages, and pull requests. Prose does not use a semicolon or a dash as
  a clause separator: write two sentences, a comma, a colon, or parentheses.

<div id='versioning'></div>

### Versioning

Each family keeps one build unit per upstream minor, under an `<upstream-minor>/` subdirectory (`images/php/8.5/`,
`images/python/3.14/`, `images/rust/1.100/`). A build unit is self-contained: its own `Dockerfile`, `VERSION`,
configuration, baked scripts, and `scripts/smoke`, with a base semantic version that advances independently of every
other upstream version. PHP 8.5 can sit at `1.3.0` while a future PHP 8.6 sits at `1.0.0`.

Two kinds of upstream change move differently:

| Upstream change                                      | What moves                                                        |
|:-----------------------------------------------------|:------------------------------------------------------------------|
| Patch (PHP 8.5.9 to 8.5.10)                          | The upstream pin and the `VERSION`, inside the same subdirectory. |
| Minor or major (PHP 8.5 to 8.6, Rust 1.100 to 1.101) | A new sibling subdirectory starting its own `VERSION` at `1.0.0`. |

A new minor diverges in its Dockerfile and configuration, so the two lines publish in parallel and each project
migrates on its own schedule. Dependabot is configured never to open that bump, because it would make it in place
inside the old subdirectory.

<div id='changing-an-image'></div>

### Changing an image

Version tags are immutable, so any change to a Dockerfile or its inputs publishes a new version.
`scripts/bump-build-unit.sh` moves everything a bump touches. It advances the patch number in `VERSION`, retags every
full tag the family README names, and repoints the upstream pins the README names to the ones the Dockerfile uses. The
lint stage compares the README against the build unit, so a bump made by hand that misses one of them fails there.

A change to what a target ships or promises also updates, in the same pull request:

- `scripts/smoke`, so the new promise is asserted and not only documented.
- The family `README.md`, which is also the Docker Hub overview of that repository, and the one-line `DESCRIPTION`
  beside it when the summary of the family changes.
- The rule, when the change carries reasoning a reader would otherwise undo.

<div id='adding-an-upstream-version'></div>

### Adding an upstream version

When a family's upstream moves to a new minor:

1. Copy the current build unit to a new `<upstream-minor>/` beside it, for example `images/php/8.5/` to
   `images/php/8.6/`.
2. Repoint its Dockerfile `FROM` to the new upstream pin and reset its `VERSION` to `1.0.0`.
3. Adjust the configuration the new upstream requires.
4. Wire the new version's lint, build, scan, audit, efficiency, smoke, and publish steps into the `Makefile` beside the
   existing version, and add its directory to `.github/dependabot.yml`.
5. List it in the family `README.md`.
6. Run `make review-<family>` until it passes.

The old version stays untouched.

<div id='adding-a-family'></div>

### Adding a family

1. Create the build unit under `images/<family>/<upstream-minor>/`, mirroring an existing one: a multi-target
   `Dockerfile`, `VERSION`, `.dockerignore`, `conf/` or `bin/` where the family needs them, and a `scripts/smoke`
   asserting the contract.
2. Add the family `README.md` one level up, from
   [the template](.claude/skills/crafting-base-images/assets/family-readme.template.md), and a `DESCRIPTION` file
   beside it holding the Docker Hub short description: one line of at most 100 bytes.
3. Wire the family into the `Makefile` aggregates (`lint-`, `build-`, `scan-`, `audit-`, `efficiency-`, `smoke-`,
   `publish-`, and `review-<family>`) and into `.github/dependabot.yml`.
4. Add it to the images table of the root [README](README.md).
5. Run `make review-<family>` until it passes.

The workflows pick the new targets up on their own, because their matrix comes from `scripts/discover-images.sh`.

<div id='handling-a-vulnerability'></div>

### Handling a vulnerability

Fix it first. In order of preference:

1. Move the upstream pin to a release that carries the fix.
2. For a package the base inherits, name it on the `apk add --no-cache --upgrade` line of the stage, and only once a
   scanner reported it.
3. For a package a build-time package manager resolves, move it in the lock or constraints file.

Only when no artifact this repository can pin carries the fix is the finding accepted, and the acceptance answers two
separate questions in separate places:

| Question                   | Where                                             | What it holds                                                         |
|:---------------------------|:--------------------------------------------------|:----------------------------------------------------------------------|
| Is the image affected?     | `vex/<family>.openvex.json`                       | An OpenVEX statement per CVE, from what was verified in the image.    |
| Does the gate block on it? | `.grype/<family>.yaml` and `.trivy/<family>.yaml` | The accepted identifier, its date, and the condition that retires it. |

`affected` statements are reported rather than silenced: the risk is disclosed, not hidden. Each policy file is
written from what that scanner printed, because the two name the same finding differently. A family that carries no
such finding has none of the three files and scans bare, which is the state to aim for. When the condition written
beside an entry is met, the entry is deleted rather than carried forward.

<div id='publication'></div>

### Publication

Merging to `main` is what publishes. The `CD` workflow runs the same gate on a native `linux/amd64` runner and a native
`linux/arm64` one, so every architecture that ships was built, scanned, audited, and smoke-tested rather than only
cross-built. It then pushes the immutable versioned tag and the floating alias to Docker Hub and to the GitHub
container registry, with a build provenance attestation, an SBOM, and the family VEX document when there is one.

- **Route every change through a pull request.** The version guard is what keeps a published tag stable. The
  publishing job does not check the registry, so a push straight to `main` republishes whatever tag the build units
  name, overwriting one that is already out there.
- **Dependabot pull requests bump themselves.** Dependabot writes no `VERSION`, so its updates would fail the guard
  every time. The `Dependabot version bump` workflow runs `scripts/bump-build-unit.sh` on the Dependabot branch and
  pushes the result with the `VERSION_BUMP_TOKEN` repository secret, because a push made with the default token fires
  no event and would leave the gate reporting against the commit before the bump.
- **The monthly rebuild repoints the aliases.** Every `FROM` pins an exact patch and distro release, so pulling that
  pin again returns the same bytes. The rebuild therefore refreshes only the packages this repository installs itself
  through `apk add`, and nothing in the inherited base layers or in the language binaries. What moves the base forward
  is a pull request for the next upstream patch.
- **The monthly rebuild also detects.** It scans the published versioned tags and opens an issue when an advisory
  names a fixed release and no accepted-risk entry covers it for that family.
- **The Docker Hub overview follows the repository.** The `Docker Hub overview` workflow publishes each family
  `README.md` as the overview of its Docker Hub repository, and its `DESCRIPTION` as the short description, whenever
  either changes on `main`. It is separate from `CD` so that editing a paragraph does not republish a tag. It needs a
  `DOCKER_HUB_TOKEN` with the read, write, and delete scope, which is more than pushing an image requires.
- **Local publication is gated the same way.** `make publish` pushes the versioned tags, and each `publish-<family>`
  target lists `review-<family>` as a prerequisite. `REGISTRY` defaults to `docker.io` and accepts any other registry
  (`make publish REGISTRY=ghcr.io`).
