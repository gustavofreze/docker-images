# Python base images

The base a Python project builds `FROM`. One Dockerfile per upstream version ships four targets: the
production `runtime`, its `development` variant, the `builder` toolchain for a project's production
build, and a `cli` tooling image a project Makefile invokes. Non-root and hardened where an
application runs it, root only where a local tooling image needs to write into a bind mount.

* [Available versions](#versions)
* [Targets and tags](#targets)
* [What it provides](#provides)
* [Usage](#usage)

<div id='versions'></div>

## Available versions

Each upstream version is a self-contained build unit under `<upstream-minor>/`, with its own
Dockerfile, `VERSION`, and smoke script, versioned independently. See the repository README, section
Versioning.

| Upstream minor | Build unit             | Base version | Upstream pin              |
|:---------------|:-----------------------|:-------------|:--------------------------|
| 3.14           | `images/python/3.14/`  | `1.0.0`      | `python:3.14.6-alpine3.24` |

<div id='targets'></div>

## Targets and tags

Every published tag is `gustavofreze/python:<upstream-minor>-<role>-<V>`, immutable, `latest`
forbidden. Each target also carries a floating alias `<upstream-minor>-<role>` that tracks its
latest rebuild. Pin the full versioned tag.

| Image                                        | Target        | Purpose                                                        |
|:---------------------------------------------|:--------------|:----------------------------------------------------------------|
| `gustavofreze/python:3.14-runtime-1.0.0`     | `runtime`     | Production interpreter. No compiler, no Poetry.                |
| `gustavofreze/python:3.14-development-1.0.0` | `development` | Development runtime: runtime plus Poetry, debugpy, bash, git.  |
| `gustavofreze/python:3.14-builder-1.0.0`     | `builder`     | Poetry and the C toolchain for the builder stage of an image.  |
| `gustavofreze/python:3.14-cli-1.0.0`         | `cli`         | Makefile tooling: Poetry, git, bash, docker CLI.               |

`development` is subordinate to `runtime`, built `FROM runtime`. It runs on a developer machine and
is never deployed. `runtime`, `development`, and `builder` all drop to the `app` user (uid 1000),
whose home is the `/app` working directory it owns. The `builder` keeps the C toolchain on
purpose, because it is the stage a project compiles its wheels in, and the multi-stage application
build discards it. The `cli` is a root-only tooling image so it can write into a bind mount owned by
the caller, audited with the CIS-DI-0001 exemption. No target exposes a port.

No target ships a `HEALTHCHECK`. These are language bases, not services: none of them starts a
long-running process of its own, so there is no liveness contract to probe. The application that
inherits the runtime declares the health check for the process it actually runs. The CIS audit
records that as a per-target CIS-DI-0006 exemption in the Makefile, beside the runner it applies to.

<div id='provides'></div>

## What it provides

Every image provides, and no consuming Dockerfile re-declares:

- A non-root runtime: the `app` user (uid 1000) with `WORKDIR /app` owned by it.
- The project-local virtual environment on `PATH` (`/app/.venv/bin`) with `VIRTUAL_ENV` set, so a
  stage that ran `poetry install` reaches its dependencies with no activation step and the runtime
  resolves the very same path.
- Container-correct interpreter defaults: `PYTHONUNBUFFERED` so a crash loses no log line,
  `PYTHONDONTWRITEBYTECODE` so nothing is written into a bind mount or a read-only layer, and
  `PYTHONFAULTHANDLER` in the runtime so a fatal signal prints a traceback.
- No installer in production. The `runtime` target uninstalls pip, which is the largest dependency
  tree the base image carries (CacheControl, requests, urllib3, msgpack, a vendored setuptools) and
  is unreachable from an application running a virtual environment the builder already populated.
  The `ensurepip` wheel stays in place, so `python3 -m ensurepip` restores the installer for the rare
  consumer that needs it. `builder`, `development`, and `cli` all ship pip 26.2, cacheless and quiet
  (`PIP_NO_CACHE_DIR`, `PIP_DISABLE_PIP_VERSION_CHECK`).
- In `builder` and `cli`: Poetry 2.4.1 configured to build the virtual environment inside the
  project (`POETRY_VIRTUALENVS_IN_PROJECT`), plus git and the C toolchain (`build-base`,
  `libffi-dev`, `openssl-dev`, `linux-headers`) for packages with no musl wheel.
- In `development` only: Poetry 2.4.1, debugpy 1.8.21, bash, and git, with the compiler that built
  debugpy pruned in the same layer.

The `cli` variant adds the docker CLI and bash on top of the builder, and stays root so it can write
into a bind-mounted project directory owned by the caller.

<div id='usage'></div>

## Usage

### As a base image

A project consumes the base in two thin files and adds only its own dependencies, code, and tuning:

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/python:3.14-development-1.0.0
COPY ./ /app
```

```dockerfile
# syntax=docker/dockerfile:1
FROM gustavofreze/python:3.14-builder-1.0.0 AS builder
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-root --only main
COPY ./ ./

FROM gustavofreze/python:3.14-runtime-1.0.0
COPY --from=builder --chown=app:app /app /app
CMD ["python3", "-m", "your_application"]
```

The virtual environment is already on `PATH`, so the runtime stage runs `python3` and every console
script the lock file installed without activating anything.

### As a tooling image

The `cli` image is invoked directly and never appears in a Dockerfile:

```shell
docker run --rm -v "$(pwd)":/app gustavofreze/python:3.14-cli-1.0.0 poetry install
docker run --rm -v "$(pwd)":/app gustavofreze/python:3.14-cli-1.0.0 python3 your-script.py
```

The full consumption rules live in the repository README, section Usage contract.
