# Contributing

Thank you for helping keep these images lean, reproducible, and safe. This document is the maintainer's side of the
repository: how a change gets in, what the gate expects, and how a tag reaches the registries. What the images are and
how to consume them is in the [README](README.md) and in each family README.

* [Requirements](#requirements)
* [Workflow](#workflow)
* [Ground rules](#ground-rules)
* [Versioning](#versioning)
* [Changing an image](#changing-an-image)
* [Adding an upstream version](#adding-an-upstream-version)
* [Adding a family](#adding-a-family)
* [Handling a vulnerability](#handling-a-vulnerability)
* [Publication](#publication)
* [Commits and pull requests](#commits-and-pull-requests)
* [Reporting a security issue](#reporting-a-security-issue)
* [License](#license)

<div id='requirements'></div>

## Requirements

Docker with BuildKit and GNU Make. Nothing else is installed on the host: every linter, scanner, and auditor runs in a
container, at the version `docker-compose.yml` names.

<div id='workflow'></div>

## Workflow

1. Fork the repository, or branch from `main` if you have write access.
2. Make the change inside one build unit, `images/<family>/<upstream-minor>/`.
3. Bump that build unit, see [Changing an image](#changing-an-image).
4. Run the gate for the family you touched until it passes:

   ```bash
   make review-<family>
   ```

5. Open a pull request against `main`.

| Command                | What it does                                                         |
|:-----------------------|:---------------------------------------------------------------------|
| `make build-<family>`  | Build the four targets of one family. No registry is involved.       |
| `make lint`            | hadolint, ShellCheck, and the family README check, for every family. |
| `make review-<family>` | The full gate for one family, from lint to smoke.                    |
| `make review`          | The full gate for every family. `make verify` is an alias.           |
| `make discover`        | Every build unit and the tags it publishes.                          |
| `make help`            | Every other command.                                                 |

A pull request runs two checks, and both must pass:

| Check         | What it asserts                                                                                    |
|:--------------|:---------------------------------------------------------------------------------------------------|
| Version guard | Every build unit the pull request touches bumped its `VERSION`.                                    |
| Review        | `make review-<family>` passes for every family, on native `linux/amd64` and `linux/arm64` runners. |

A scanner database moves on its own, so the gate can turn red on a tree nobody touched. When that happens the fix
belongs in the same pull request, see [Handling a vulnerability](#handling-a-vulnerability).

<div id='ground-rules'></div>

## Ground rules

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

## Versioning

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

## Changing an image

Version tags are immutable, so any change to a Dockerfile or its inputs publishes a new version. One command moves
everything a bump touches:

```bash
./scripts/bump-build-unit.sh images/<family>/<upstream-minor>
```

It advances the patch number in `VERSION`, retags every full tag the family README names, and repoints the upstream
pins the README names to the ones the Dockerfile uses. The lint stage compares the README against the build unit, so a
bump made by hand that misses one of them fails there.

A change to what a target ships or promises also updates, in the same pull request:

- `scripts/smoke`, so the new promise is asserted and not only documented.
- The family `README.md`, which is also the Docker Hub overview of that repository, and the one-line `DESCRIPTION`
  beside it when the summary of the family changes.
- The rule, when the change carries reasoning a reader would otherwise undo.

<div id='adding-an-upstream-version'></div>

## Adding an upstream version

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

## Adding a family

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

## Handling a vulnerability

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

## Publication

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

<div id='commits-and-pull-requests'></div>

## Commits and pull requests

- Write the subject as one imperative sentence that says what the change does, ending with a period:
  `Upgrade the inherited openssl and stop reporting accepted risk.`
- Keep one concern per pull request. A gate that went red for an unrelated upstream reason is fixed in the same pull
  request, and its description says so.
- In the description, state what was verified and what was not, for example which `make review-<family>` runs passed
  locally.
- Pull requests are squash-merged, so the pull request title becomes the commit subject on `main`.

<div id='reporting-a-security-issue'></div>

## Reporting a security issue

Do not open a public issue for a vulnerability in this repository or in how an image is built. Report it privately
through [GitHub security advisories](https://github.com/gustavofreze/docker-images/security/advisories/new).

A CVE in an upstream package that a scanner already reports is not a private matter: open a regular
[issue](https://github.com/gustavofreze/docker-images/issues) naming the image tag and the identifier.

<div id='license'></div>

## License

By contributing, you agree that your contribution is licensed under the [MIT](LICENSE) license of this repository.
