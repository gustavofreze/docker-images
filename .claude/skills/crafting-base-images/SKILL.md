---
name: crafting-base-images
description: Author or extend a container base image family the symmetric, lean, secure way, and wire it into the repository gate. Use when creating a new image family, adding a build target to an existing family, adding an upstream version, or making a base Dockerfile symmetric with its siblings. Also /crafting-base-images.
---

# Craft base image

Authors or extends a base image family under `images/` so it matches its siblings, stays lean and
non-root, and is wired into the Makefile, the smoke assertions, its `.dockerignore`, and the family
README.

Target: a family under `images/<family>/`, from the request.

## When to use

- Creating a new image family.
- Adding a target to an existing family.
- Adding a new upstream version of a family that already exists.
- Making an existing base Dockerfile symmetric with the other families.

## When NOT to use

- Writing a project's consumer Dockerfile. That is two thin comment-free files. See the
  `docker-images` rule, § Consuming.
- Bumping only a `VERSION` or an upstream pin with no structural change.
- Publishing images to a registry. This skill authors the files, the Makefile and the CD workflow
  publish.

## Rules applied

The `docker-images` rule is normative: the authoring invariants (§ Authoring, § Syntax, § Hermetic
builds, § Lean layers), the pin and cooldown policy, and § Where the reasoning lives. The
`shell-scripts` rule governs every `RUN` body, every baked script, and every `scripts/smoke`. This
skill sequences the work and gates it, it does not restate the rules.

## Stage vocabulary

Four stage names are the closed vocabulary. Each names what the image is, and a family ships only
the stages its role calls for.

- **`builder`**. The compilation base a project inherits via `FROM`. It carries the toolchain that
  installs dependencies and compiles them, and the multi-stage build discards it. It keeps that
  toolchain on purpose.
- **`runtime`**. The production image the platform runs. No build tools, no development tooling, no
  installer it does not need.
- **`cli`**. Local command-line tooling for one-shot commands, invoked from a project Makefile over
  a bind mount. The one target that legitimately ends as root.
- **`development`**. A variant of `runtime` built `FROM runtime`, adding local development tooling.
  It runs on a developer machine and is never deployed. Subordinate to `runtime`, not a peer.

## Tag scheme

Every published tag is `gustavofreze/<family>:<upstream-minor>-<role>-<semver>`, where `role` is
identical to the stage name. There is no bare tag. Version tags are immutable, so any input change
bumps the build unit `VERSION`, and the CI version guard fails a pull request that skips the bump.
`latest` is forbidden. Each stage also carries a floating alias `<upstream-minor>-<role>` that the
weekly security rebuild republishes. That rebuild refreshes only the packages this repository installs
itself through `apk add`, never the inherited base layers, because the `FROM` pin returns the same
bytes every time. Dependabot opening a pull request for the next upstream patch is what moves the base
forward.

## Symmetry template

Every base Dockerfile matches its siblings on all of these:

1. The literal first line is `# syntax=docker/dockerfile:1`.
2. No comment anywhere else. The only other `#` line permitted is an inline `hadolint ignore=<rule>`,
   which is a directive. Rationale goes in the `docker-images` rule, § Where the reasoning lives.
3. A full OCI label set on every target built from a distinct upstream base, and a `title` and
   `description` override on each derived target. Entries ordered by key length ascending, ties
   alphabetically.
4. Targets ordered base to derivative, never a derivative before the stage it builds on.
5. A uniform package pattern: no-cache installs, build-only dependencies under a virtual group
   deleted in the same `RUN`, one `RUN` per concern chained with `&&`. The `builder` target is the
   deliberate exception that keeps its toolchain.
6. A non-root last `USER` on every target a project runs, with `WORKDIR` owned by that user. A target
   that stays root carries an inline `hadolint ignore=DL3002` and is audited with the matching CIS
   exemption in the Makefile.
7. A `HEALTHCHECK` on every target that starts a long-running process of its own, and none on the
   targets with nothing to probe. A target with no health check is audited with the CIS-DI-0006
   exemption.
8. Baked drop-in configuration namespaced and numbered (`zz-gustavofreze-<NN>-*` in a `conf.d`), so
   ordering is explicit and a derived target replaces a single drop-in by reusing its file name.
9. A baked executable script at `/usr/local/bin/<name>`, copied with `COPY --chmod=755`, carrying a
   shebang, sourced from the family's `bin/`. Every reference uses that same path.

## Smoke contract

`scripts/smoke` boots a throwaway container per target and asserts what that target's class promises.
It sources the shared library through `${SMOKE_LIB}` and adds only the family-specific assertions.

- **Service target**: runs as a non-root user, its baked health check drives the container to
  healthy, the hardening is active, the pinned versions are present, and no build or development
  tooling survives into the production surface.
- **Builder target**: its toolchain versions are pinned and present, it runs non-root, and its
  working directory is the expected application root.
- **One-shot or CLI target**: its pinned tools answer `--version`, and its working directory is the
  expected application root.

Assert absence as well as presence. A runtime that quietly regained `bash`, a compiler, or an
installer fails its own smoke, which is what keeps the production surface from drifting back.

## Assembly order

For a new family or target:

1. Create the build unit at `images/<family>/<upstream-minor>/` (the segment is the exact minor from
   the `FROM` pin) with a multi-target `Dockerfile` following the symmetry template, a `VERSION`
   holding the base semantic version, a `.dockerignore` beside it, and `conf/` or `bin/` when the
   family bakes configuration or scripts.
2. For a new family, add `images/<family>/README.md` one level up as the umbrella, by copying
   `assets/family-readme.template.md` and filling each slot. This file is pasted verbatim into the
   Docker Hub repository overview, which renders no HTML and has no repository context, so it carries
   no anchor `div` and every link in it is absolute. Every family README keeps the template's seven
   sections in the same order, so a reader finds the same thing in the same place. The template marks
   the two slots that are conditional: the service subsection exists only for a family whose targets
   start a long-running process, and the VEX paragraph only for a family that publishes one. Omit a
   conditional slot rather than inventing content to fill it.
3. Write `scripts/smoke` sourcing the shared library and asserting what each target's class promises,
   per § Smoke contract.
4. Pin the upstream image to an exact tag (patch and distro release) and honor the 7-day cooldown.
   Pin every tool the same way, and checksum-verify anything fetched over plain HTTPS.
5. Wire the family into the Makefile: its coordinate variables at the top, then `lint-<family>`,
   `build-<family>`, `scan-<family>`, `audit-<family>`, `efficiency-<family>`, `smoke-<family>`,
   `publish-<family>`, and a `review-<family>` chaining them in gate order. Add each to its aggregate.
6. Nothing to wire in the workflows. Their matrix comes from `scripts/discover-images.sh`, which reads
   the Dockerfile's named build stages and keeps the four of the closed vocabulary. Any other stage,
   such as one pinning an upstream image a target copies a binary out of, publishes no tag. Name that
   stage rather than writing a bare `COPY --from=<image>`, so Dependabot sees the pin.

For a scan finding that cannot be fixed locally, write a statement in the family VEX document at
`vex/<family>.openvex.json`: `not_affected` with an OpenVEX justification and an impact statement
recording what you verified inside the image, or `affected` with an action statement when the product
carries it and no fix exists upstream. Both scanners read it, and CD publishes it as an attestation. A
risk that is real and unremediable, and that the gate should not stop on, gets an entry in
`.grype/<family>.yaml` and one in `.trivy/<family>.yaml`, each carrying its acceptance date and the
condition that retires it. Write each from what that scanner actually printed: they name the same
finding differently, by GO advisory and by CVE, and they disagree on severity, so suppress only what
each one's own threshold stops on. Every document here is per family and the Makefile passes each only
to its own, so never put any of them at the repository root. See the `docker-images` rule,
§ Vulnerability acceptance.

## Completeness gate

Run `make review-<family>` and let it pass. It is green only when, for every target the family ships:

- [ ] The Dockerfile lints clean and its `RUN` bodies pass ShellCheck.
- [ ] Every target a project runs has a non-root last user, with hardening active.
- [ ] The image conforms to the CIS Docker Benchmark, with any exemption named and justified.
- [ ] No fixable HIGH or CRITICAL vulnerability remains.
- [ ] Layer efficiency stays within the `.dive-ci` thresholds.
- [ ] The smoke assertions all pass.

Any input change also bumps the family `VERSION`, since version tags are immutable.

## Does not do

- Does not build or publish to a registry. It authors files, `make build` and the CD workflow act.
- Does not touch a project's consumer Dockerfile.
- Does not commit, push, branch, merge, rebase, or tag.
