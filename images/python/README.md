# gustavofreze/python

Hardened, reproducible Python base images. One Dockerfile per upstream version ships four targets: the production
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
- **Also published as:** `ghcr.io/gustavofreze/python`
- **Architectures:** `linux/amd64`, `linux/arm64`
- **Supply chain:** every tag ships a build provenance attestation, an SBOM, and an OpenVEX analysis
- **License:** [MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)

## Supported tags

Every tag is `<upstream-minor>-<target>-<version>`. There is no bare tag and `latest` is forbidden. Version tags are
immutable, so any change to a Dockerfile or its inputs publishes a new `<version>` instead of rewriting one. Pin the
full versioned tag in a project.

| Tag                      | Alias              | Target        | Purpose                                                       |
|:-------------------------|:-------------------|:--------------|:--------------------------------------------------------------|
| `3.14-runtime-1.0.1`     | `3.14-runtime`     | `runtime`     | Production interpreter. No compiler, no installer, no Poetry. |
| `3.14-development-1.0.1` | `3.14-development` | `development` | Development runtime: runtime plus Poetry, debugpy, bash, git. |
| `3.14-builder-1.0.1`     | `3.14-builder`     | `builder`     | Poetry and the C toolchain for the builder stage of an image. |
| `3.14-cli-1.0.1`         | `3.14-cli`         | `cli`         | Makefile tooling: Poetry, git, bash, curl.                    |

All four are built from one multi-target
[Dockerfile](https://github.com/gustavofreze/docker-images/blob/main/images/python/3.14/Dockerfile), pinned to
`python:3.14.7-alpine3.24`. The alias tracks the latest rebuild of its target and is meant for a local experiment, never
for a project.

## Image variants

`development` is subordinate to `runtime`, built `FROM runtime`. It runs on a developer machine and is never deployed.
`runtime`, `development`, and `builder` all drop to the `app` user (uid 1000), whose home is the `/app` working
directory it owns. The `builder` keeps the C toolchain on purpose, because it is the stage a project compiles its wheels
in, and the multi-stage application build discards it. The `cli` is a root-only tooling image so it can write into a
bind mount owned by the caller.

No target ships a `HEALTHCHECK`. These are language bases, not services: none of them starts a long-running process of
its own, so there is no liveness contract to probe. The application that inherits the runtime declares the health check
for the process it actually runs. No target exposes a port.

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- A non-root runtime: the `app` user (uid 1000) with `WORKDIR /app` owned by it.
- The project-local virtual environment on `PATH` (`/app/.venv/bin`) with `VIRTUAL_ENV` set, so a stage that ran
  `poetry install` reaches its dependencies with no activation step and the runtime resolves the very same path.
- Container-correct interpreter defaults: `PYTHONUNBUFFERED` so a crash loses no log line, `PYTHONDONTWRITEBYTECODE` so
  nothing is written into a bind mount or a read-only layer, and `PYTHONFAULTHANDLER` in the runtime so a fatal signal
  prints a traceback.
- No installer in production. The `runtime` target uninstalls pip, which is the largest dependency tree the base image
  carries (CacheControl, requests, urllib3, msgpack, a vendored setuptools) and is unreachable from an application
  running a virtual environment the builder already populated. The `ensurepip` wheel stays in place, so
  `python3 -m ensurepip` restores the installer for the rare consumer that needs it. `builder`, `development`, and `cli`
  all ship pip 26.2, cacheless and quiet (`PIP_NO_CACHE_DIR`, `PIP_DISABLE_PIP_VERSION_CHECK`).
- In `builder` and `cli`: Poetry 2.4.1 configured to build the virtual environment inside the project
  (`POETRY_VIRTUALENVS_IN_PROJECT`), plus git and the C toolchain (`build-base`, `libffi-dev`, `openssl-dev`,
  `linux-headers`) for packages with no musl wheel.
- In `development` only: Poetry 2.4.1, debugpy 1.8.21, bash, and git, with the compiler that built debugpy pruned in the
  same layer.

The `cli` variant adds bash and curl on top of the builder, and stays root so it can write into a bind-mounted project
directory owned by the caller.

## How to use this image

### As a base image

A project consumes the base in two thin files and adds only its own dependencies, code, and tuning:

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/python:3.14-development-1.0.1
COPY ./ /app
```

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/python:3.14-builder-1.0.1 AS builder
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-root --only main
COPY ./ ./

FROM gustavofreze/python:3.14-runtime-1.0.1
COPY --from=builder --chown=app:app /app /app
CMD ["python3", "-m", "your_application"]
```

The virtual environment is already on `PATH`, so the runtime stage runs `python3` and every console script the lock file
installed without activating anything.

### As a tooling image

The `cli` image is invoked directly and never appears in a Dockerfile:

```shell
docker run --rm -v "$(pwd)":/app gustavofreze/python:3.14-cli-1.0.1 poetry install
docker run --rm -v "$(pwd)":/app gustavofreze/python:3.14-cli-1.0.1 python3 your-script.py
```

The rules that hold across every family live in the
[usage contract](https://github.com/gustavofreze/docker-images#usage-contract).

## Verification

No tag is published before it passes the full gate: hadolint and ShellCheck on every Dockerfile and `RUN` body, a Trivy
and Grype scan for fixable HIGH and CRITICAL vulnerabilities, a Dockle audit against the CIS Docker Benchmark, a dive
layer-efficiency check, and a smoke suite that boots throwaway containers and asserts the runtime contract (non-root
user, interpreter defaults, virtual environment on `PATH`, pinned tool versions, and no installer or compiler in the
production surface). The gate runs on a native `linux/amd64` runner and a native `linux/arm64` one, so every
architecture that ships was actually built, scanned, audited, and smoke-tested.

Every tag also carries an [OpenVEX](https://openvex.dev) analysis as a cosign attestation, stating per CVE whether the
image is genuinely affected. A scanner that reads it applies the analysis on its own:

```shell
trivy image --vex oci gustavofreze/python:3.14-runtime-1.0.1
```

`affected` statements are reported, not silenced, which is the point: the risk is disclosed rather than hidden. The
document is also versioned at
[vex/python.openvex.json](https://github.com/gustavofreze/docker-images/blob/main/vex/python.openvex.json), so it can be
passed as a file or a URL.

## License

[MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)
