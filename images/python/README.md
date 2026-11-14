# gustavofreze/python

Hardened, reproducible Python base images. One Dockerfile per upstream version ships four targets: the production
`runtime`, its `development` variant, the `builder` for a project's production build, and a `cli` tooling image a
project Makefile invokes.

## Quick reference

- **Maintained by:** [Gustavo Freze](https://github.com/gustavofreze)
- **Source:** [gustavofreze/docker-images](https://github.com/gustavofreze/docker-images)
- **File an issue:** [docker-images/issues](https://github.com/gustavofreze/docker-images/issues)
- **Also published as:** `ghcr.io/gustavofreze/python`
- **Architectures:** `linux/amd64`, `linux/arm64`
- **Supply chain:** every tag ships a build provenance attestation, an SBOM, and an OpenVEX analysis
- **License:** [MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)

## Supported tags

| Tag                       | Alias              | Purpose                                                       |
|:--------------------------|:-------------------|:--------------------------------------------------------------|
| `3.14-runtime-1.0.12`     | `3.14-runtime`     | Production interpreter. No compiler, no installer, no Poetry. |
| `3.14-development-1.0.12` | `3.14-development` | Local development: runtime plus Poetry, debugpy, bash, git.   |
| `3.14-builder-1.0.12`     | `3.14-builder`     | Poetry and the C toolchain for the builder stage of an image. |
| `3.14-cli-1.0.12`         | `3.14-cli`         | Makefile tooling: Poetry, git, bash, curl.                    |

Every tag is `<upstream-minor>-<target>-<version>`. There is no bare tag and `latest` is forbidden.

- **Versioned tag.** Immutable and reproducible. It moves only when you bump it, so take it for anything that ships.
- **Alias.** Tracks the latest rebuild of its target, the monthly security rebuild included, and never crosses an
  upstream minor: `3.14-runtime` stays on 3.14. It moves only when the client re-pulls, which suits `cli` and local
  development.

All four are built from one multi-target
[Dockerfile](https://github.com/gustavofreze/docker-images/blob/main/images/python/3.14/Dockerfile), pinned to
`python:3.14.10-alpine3.24`. The tools it installs are pinned in
[requirements.txt](https://github.com/gustavofreze/docker-images/blob/main/images/python/3.14/requirements.txt), and
the whole tree they resolve to in the constraints file beside it.

## Image variants

| Target        | Runs as          | On top of the base                                                     |
|:--------------|:-----------------|:-----------------------------------------------------------------------|
| `runtime`     | `app` (uid 1000) | Nothing. pip is uninstalled, and there is no compiler and no Poetry.   |
| `development` | `app` (uid 1000) | `runtime` plus pip, Poetry 2, debugpy, bash, git.                      |
| `builder`     | `app` (uid 1000) | pip, Poetry 2, git, and a C toolchain for packages with no musl wheel. |
| `cli`         | root             | `builder` plus bash and curl.                                          |

- `development` is built `FROM runtime`. It runs on a developer machine and is never deployed.
- `builder` keeps the C toolchain (`build-base`, `libffi-dev`, `openssl-dev`, `linux-headers`) on purpose. It is the
  stage a project compiles its wheels in, and the multi-stage application build discards it.
- `cli` stays root so it can write into a bind mount owned by the caller.
- No target ships a `HEALTHCHECK` or exposes a port. These are language bases, not services, so the application that
  inherits the runtime declares the health check for the process it actually runs.

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- **A non-root runtime.** The `app` user (uid 1000), whose home is the `/app` working directory it owns.
- **Current system libraries.** openssl, libuuid, and zlib are upgraded to what the Alpine index serves at build time,
  instead of aging in place between base releases.
- **The virtual environment on `PATH`.** `/app/.venv/bin` with `VIRTUAL_ENV` set, so a stage that ran `poetry install`
  reaches its dependencies with no activation step and the runtime resolves the very same path.
- **Container-correct interpreter defaults.** `PYTHONUNBUFFERED` so a crash loses no log line,
  `PYTHONDONTWRITEBYTECODE` so nothing is written into a bind mount or a read-only layer, and `PYTHONFAULTHANDLER` in
  the runtime so a fatal signal prints a traceback.
- **No installer in production.** The `runtime` uninstalls pip, the largest dependency tree the base image carries,
  which an application running a virtual environment never reaches. The `ensurepip` wheel stays in place, so
  `python3 -m ensurepip` restores the installer for the rare consumer that needs it.
- **A cacheless, quiet pip** wherever pip ships (`PIP_NO_CACHE_DIR`, `PIP_DISABLE_PIP_VERSION_CHECK`).
- **Poetry building inside the project** (`POETRY_VIRTUALENVS_IN_PROJECT`), in `builder`, `cli`, and `development`.

## How to use this image

### As a base image

A project consumes the base in two thin files and adds only its own dependencies, code, and tuning:

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/python:3.14-development-1.0.12
COPY ./ /app
```

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/python:3.14-builder-1.0.12 AS builder
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-root --only main
COPY ./ ./

FROM gustavofreze/python:3.14-runtime-1.0.12
COPY --from=builder --chown=app:app /app /app
CMD ["python3", "-m", "your_application"]
```

The virtual environment is already on `PATH`, so the runtime stage runs `python3` and every console script the lock file
installed without activating anything.

### As a tooling image

The `cli` image is invoked directly and never appears in a Dockerfile:

```shell
docker run --rm -v "$(pwd)":/app gustavofreze/python:3.14-cli-1.0.12 poetry install
docker run --rm -v "$(pwd)":/app gustavofreze/python:3.14-cli-1.0.12 python3 your-script.py
```

The rules that hold across every family live in the
[usage contract](https://github.com/gustavofreze/docker-images#usage-contract).

## Verification

No tag is published before it passes the full
[gate](https://github.com/gustavofreze/docker-images#verification-gate), on a native `linux/amd64` runner and a native
`linux/arm64` one:

| Stage      | Tool                 | What it checks                                 |
|:-----------|:---------------------|:-----------------------------------------------|
| Lint       | hadolint, ShellCheck | Every Dockerfile and every `RUN` body.         |
| Scan       | Trivy and Grype      | Fixable HIGH and CRITICAL vulnerabilities.     |
| Audit      | Dockle               | The CIS Docker Benchmark.                      |
| Efficiency | dive                 | Wasted layer space.                            |
| Smoke      | throwaway containers | The runtime contract, in throwaway containers. |

The smoke suite asserts the non-root user, the interpreter defaults, the virtual environment on `PATH`, the pinned tool
versions, and the absence of an installer or a compiler in the production surface.

Every tag also carries an [OpenVEX](https://openvex.dev) analysis as a cosign attestation, stating per CVE whether the
image is genuinely affected. A scanner that reads it applies the analysis on its own:

```shell
trivy image --vex oci gustavofreze/python:3.14-runtime-1.0.12
```

`affected` statements are reported, not silenced, which is the point: the risk is disclosed rather than hidden. The
document is also versioned at
[vex/python.openvex.json](https://github.com/gustavofreze/docker-images/blob/main/vex/python.openvex.json), so it can be
passed as a file or a URL.

## License

[MIT](https://github.com/gustavofreze/docker-images/blob/main/LICENSE)
