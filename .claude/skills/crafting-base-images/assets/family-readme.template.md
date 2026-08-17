# gustavofreze/<family>

<One sentence naming the family and its posture, in the shape "Hardened, reproducible <X> base
images."> One Dockerfile per upstream version ships <N> targets: <one clause per target, naming its
role and its purpose>. <One sentence on hardening posture: non-root and hardened where an application
runs it, root only where a local tooling image needs to write into a bind mount.>

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
- **Also published as:** `ghcr.io/gustavofreze/<family>`
- **Architectures:** `linux/amd64`, `linux/arm64`
- **Supply chain:** every tag ships a build provenance attestation and an SBOM<, and an OpenVEX
  analysis when the family publishes one>
- **License:** [MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)

## Supported tags

Every tag is `<upstream-minor>-<target>-<version>`. There is no bare tag and `latest` is forbidden.
Version tags are immutable, so any change to a Dockerfile or its inputs publishes a new `<version>`
instead of rewriting one. Pin the full versioned tag in a project.

| Tag                                | Alias                      | Target   | Purpose    |
|:-----------------------------------|:---------------------------|:---------|:-----------|
| `<minor>-<target>-<V>`             | `<minor>-<target>`         | `<target>` | <one line> |

All four are built from one multi-target
[Dockerfile](https://github.com/gustavofreze/docker-images/blob/main/images/<family>/<minor>/Dockerfile),
pinned to `<upstream pin>`. The alias tracks the latest rebuild of its target and is meant for a local
experiment, never for a project.

## Image variants

<One paragraph: the subordination of `development` to `runtime`, the non-root user each target drops
to, the named root exception, and what the builder keeps or discards.>

<One paragraph on the base-image or health-check posture that is specific to this family: which
targets ship a `HEALTHCHECK` and which do not and why, the port posture, and any consequence the
family inherits from the upstream tag it pins.>

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- <provision>
- <provision>

<One line on what each non-runtime target adds on top, for example the builder's toolchain contents
and the cli's tooling.>

## How to use this image

### As a base image

A project consumes the base in two thin files and adds only its own dependencies, code, and tuning:

```dockerfile
# syntax=docker/dockerfile:1
<the development-target consumption snippet>
```

```dockerfile
# syntax=docker/dockerfile:1
<the builder-plus-runtime multi-stage consumption snippet>
```

### As a tooling image

The `cli` image is invoked directly and never appears in a Dockerfile:

```shell
<one or two representative invocations over a bind mount>
```

<### As a service, only when a target of this family starts a long-running process of its own. A
family whose targets start none omits this subsection rather than inventing a service for it.>

The rules that hold across every family live in the
[usage contract](https://github.com/gustavofreze/docker-images#usage-contract).

## Verification

No tag is published before it passes the full gate: hadolint and ShellCheck on every Dockerfile and
`RUN` body, a Trivy and Grype scan for fixable HIGH and CRITICAL vulnerabilities, a Dockle audit
against the CIS Docker Benchmark, a dive layer-efficiency check, and a smoke suite that boots
throwaway containers and asserts the runtime contract (<the family's own assertions, named>). The gate
runs on a native `linux/amd64` runner and a native `linux/arm64` one, so every architecture that ships
was actually built, scanned, audited, and smoke-tested.

<Only when the family publishes a VEX: one paragraph stating that every tag carries an OpenVEX
analysis as a cosign attestation, a shell block showing a scanner reading it, and the note that
`affected` statements are reported rather than silenced. A family with no VEX points at the repository
README instead.>

## License

[MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)
