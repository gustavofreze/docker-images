# gustavofreze/rust

Hardened, reproducible Rust base images. One Dockerfile per upstream version ships four targets: the production
`runtime`, its `development` variant, the `builder` toolchain for a project's production build, and a `cli` tooling
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
- **Also published as:** `ghcr.io/gustavofreze/rust`
- **Architectures:** `linux/amd64`, `linux/arm64`
- **Supply chain:** every tag ships a build provenance attestation and an SBOM
- **License:** [MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)

## Supported tags

Every tag is `<upstream-minor>-<target>-<version>`. There is no bare tag and `latest` is forbidden. Version tags are
immutable, so any change to a Dockerfile or its inputs publishes a new `<version>` instead of rewriting one. Each
target also carries a floating alias, and a project may take either form.

| Tag                       | Alias               | Target        | Purpose                                                          |
|:--------------------------|:--------------------|:--------------|:-----------------------------------------------------------------|
| `1.100-runtime-1.0.0`     | `1.100-runtime`     | `runtime`     | Production base for a static binary. No toolchain, no shell kit. |
| `1.100-development-1.0.0` | `1.100-development` | `development` | Development runtime: runtime plus Cargo, Clippy, rustfmt, git.   |
| `1.100-builder-1.0.0`     | `1.100-builder`     | `builder`     | Cargo and the musl toolchain for the builder stage of an image.  |
| `1.100-cli-1.0.0`         | `1.100-cli`         | `cli`         | Makefile tooling: Cargo, Clippy, rustfmt, git, bash, curl.       |

All four are built from one multi-target
[Dockerfile](https://github.com/gustavofreze/docker-images/blob/main/images/rust/1.100/Dockerfile), pinned to
`rust:1.100.0-alpine3.24` for the toolchain and to `alpine:3.24.4` for the runtime. The alias tracks the latest rebuild
of its target and never crosses an upstream minor, so `1.100-runtime` stays on 1.100. Take the versioned tag for
anything that ships, because it is reproducible and moves only when you bump it. Take the alias when the monthly
security rebuild arriving without a pull request is worth more than that, which is usually the case for `cli` and for
local development. An alias moves only when the client re-pulls.

## Image variants

`development` is subordinate to `runtime`, built `FROM runtime`. It runs on a developer machine and is never deployed.
`runtime`, `development`, and `builder` all drop to the `app` user (uid 1000), whose home is the `/app` working
directory it owns. The `builder` keeps the whole toolchain on purpose, because it is the stage a project compiles its
binary in, and the multi-stage application build discards it. The `cli` is a root-only tooling image so it can write
into a bind mount owned by the caller.

The `runtime` is not built on the Rust image at all. A Rust release binary targeting musl links statically, so it needs
no interpreter, no standard library on disk, and no compiler runtime, and the production image is a pinned Alpine with
its certificate bundle and an unprivileged user, around 13 MB. It ships as a single layer: the Alpine root file system
is prepared in a stage of its own and copied whole into an empty image, so a package upgraded at build time replaces
the old copy instead of hiding it in a layer underneath. No target ships a `HEALTHCHECK`. These are language bases,
not services: none of them starts a long-running process of its own, so there is no liveness contract to probe. The
application that inherits the runtime declares the health check for the process it actually runs. No target exposes a
port.

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- A non-root runtime: the `app` user (uid 1000) with `WORKDIR /app` owned by it.
- The Alpine certificate bundle at `/etc/ssl/certs/ca-certificates.crt`, so a binary that verifies TLS against the
  system store works unchanged. A project that trusts a private authority adds the `ca-certificates` package itself.
- A current zlib. The upstream bases ship whatever `zlib` was current when they were tagged, and it ages in place
  between base releases, so every image here upgrades it to what the Alpine index serves at build time. A consuming
  Dockerfile does not need to repeat it.
- `RUST_BACKTRACE=1` in `runtime` and `development`, so a panic prints its backtrace instead of a hint to set the
  variable.
- No toolchain in production. The `runtime` target carries no Cargo, no rustc, no linker, no git, no bash, and no
  curl, and the smoke suite asserts each absence.
- In `builder`: rustc and Cargo 1.100.0 targeting musl, with the gcc linker and `musl-dev` the upstream image ships. A
  release build produces a statically linked binary with no flag, and the smoke suite proves it by running one in the
  runtime.
- In `cli` and `development`: the same toolchain plus Clippy, rustfmt, bash, and git.

The `cli` variant adds curl on top, and stays root so it can write into a bind-mounted project directory owned by the
caller. `CARGO_HOME` stays at the upstream `/usr/local/cargo`, which the upstream image leaves writable by any user, so
the `app` user fetches crates into it with no extra configuration.

## How to use this image

### As a base image

A project consumes the base in two thin files and adds only its own dependencies, code, and tuning:

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/rust:1.100-development-1.0.0
COPY ./ /app
```

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/rust:1.100-builder-1.0.0 AS builder
COPY Cargo.toml Cargo.lock ./
RUN cargo fetch --locked
COPY ./ ./
RUN cargo build --release --locked --offline

FROM gustavofreze/rust:1.100-runtime-1.0.0
COPY --from=builder --chown=app:app /app/target/release/your-application /app/your-application
CMD ["/app/your-application"]
```

`cargo fetch` reads only the manifest and the lock file, so the dependency download is its own layer and a code change
does not repeat it. A crate that links a C library needs that library's development package in the builder stage and
its shared object in the runtime stage, both added by the project.

### As a tooling image

The `cli` image is invoked directly and never appears in a Dockerfile:

```shell
docker run --rm -v "$(pwd)":/app gustavofreze/rust:1.100-cli-1.0.0 cargo clippy --all-targets -- -D warnings
docker run --rm -v "$(pwd)":/app gustavofreze/rust:1.100-cli-1.0.0 cargo fmt --check
```

The rules that hold across every family live in the
[usage contract](https://github.com/gustavofreze/docker-images#usage-contract).

## Verification

No tag is published before it passes the full gate: hadolint and ShellCheck on every Dockerfile and `RUN` body, a Trivy
and Grype scan for fixable HIGH and CRITICAL vulnerabilities, a Dockle audit against the CIS Docker Benchmark, a dive
layer-efficiency check, and a smoke suite that boots throwaway containers and asserts the runtime contract (non-root
user, pinned toolchain version, linters only where they belong, no toolchain in the production surface, and a release
binary compiled in the builder running in the runtime). The gate runs on a native `linux/amd64` runner and a native
`linux/arm64` one, so every architecture that ships was actually built, scanned, audited, and smoke-tested.

This family carries no finding it cannot fix locally, so it publishes no OpenVEX document. The
[repository README](https://github.com/gustavofreze/docker-images#publication) describes what a family publishes when
it does.

## License

[MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)
