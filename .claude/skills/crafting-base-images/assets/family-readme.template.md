# gustavofreze/<family>

<One sentence naming the family and its posture, in the shape "Hardened, reproducible <X> base
images."> One Dockerfile per upstream version ships <N> targets: <one clause per target, naming its
role and its purpose>.

## Quick reference

- **Maintained by:** [Gustavo Freze](https://github.com/gustavofreze)
- **Source:** [gustavofreze/docker-images](https://github.com/gustavofreze/docker-images)
- **File an issue:** [docker-images/issues](https://github.com/gustavofreze/docker-images/issues)
- **Also published as:** `ghcr.io/gustavofreze/<family>`
- **Architectures:** `linux/amd64`, `linux/arm64`
- **Supply chain:** every tag ships a build provenance attestation and an SBOM<, and an OpenVEX
  analysis when the family publishes one, or "and carries no accepted risk" when it scans bare>
- **License:** [MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)

## Supported tags

| Tag                    | Alias              | Purpose    |
|:-----------------------|:-------------------|:-----------|
| `<minor>-<target>-<V>` | `<minor>-<target>` | <one line> |

Every tag is `<upstream-minor>-<target>-<version>`. There is no bare tag and `latest` is forbidden.

- **Versioned tag.** Immutable and reproducible. It moves only when you bump it, so take it for anything that ships.
- **Alias.** Tracks the latest rebuild of its target, the monthly security rebuild included, and never crosses an
  upstream minor: `<minor>-runtime` stays on <minor>. It moves only when the client re-pulls, which suits `cli` and
  local development.

All four are built from one multi-target
[Dockerfile](https://github.com/gustavofreze/docker-images/blob/main/images/<family>/<minor>/Dockerfile),
pinned to `<upstream pin>`. <One sentence on where every other tool is pinned. Name in backticks only
the pins of the family's own base images, because the documentation check and the automated bump keep
exactly those in step with the Dockerfile.>

## Image variants

| Target        | Runs as        | On top of the base |
|:--------------|:---------------|:-------------------|
| `runtime`     | <user> (uid N) | <one line>         |
| `development` | <user> (uid N) | <one line>         |
| `builder`     | <user> (uid N) | <one line>         |
| `cli`         | root           | <one line>         |

<A family with a target that starts a long-running process adds a "Health check" column.>

- `development` is built `FROM runtime`. It runs on a developer machine and is never deployed.
- <What the builder keeps or discards, and why.>
- `cli` stays root so it can write into a bind mount owned by the caller.
- <The health-check and port posture, and any consequence the family inherits from the upstream tag
  it pins.>

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- **<Provision.>** <What it is, in one or two lines. Reasoning a maintainer needs goes in the rule,
  under "Where the reasoning lives", not here.>
- **<Provision.>** <...>

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

No tag is published before it passes the full
[gate](https://github.com/gustavofreze/docker-images#verification-gate), on a native `linux/amd64` runner and a native
`linux/arm64` one:

| Stage      | Tool                 | What it checks                             |
|:-----------|:---------------------|:-------------------------------------------|
| Lint       | hadolint, ShellCheck | Every Dockerfile and every `RUN` body.     |
| Scan       | Trivy and Grype      | Fixable HIGH and CRITICAL vulnerabilities. |
| Audit      | Dockle               | The CIS Docker Benchmark.                  |
| Efficiency | dive                 | Wasted layer space.                        |
| Smoke      | throwaway containers | <the family's own assertions, named>       |

<When the family publishes a VEX: one paragraph stating that every tag carries an OpenVEX analysis as
a cosign attestation, a shell block showing a scanner reading it, and the note that `affected`
statements are reported rather than silenced. When it does not: one paragraph stating that the family
carries no accepted risk and scans bare, and a shell block scanning one tag.>

## License

[MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)
