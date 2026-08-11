# =============================================================================
# Makefile: container base images
# Requires: GNU Make 4.x+, Docker
# =============================================================================

# ---- Make behavior ----------------------------------------------------------
MAKEFLAGS += --no-print-directory --warn-undefined-variables
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.ONESHELL:

SHELL       := bash
.SHELLFLAGS := -eu -o pipefail -c

# ---- PHP image coordinates --------------------------------------------------
PHP_MINOR     := 8.5
PHP_VERSION   := $(shell cat images/php/8.5/VERSION)
PHP_NAMESPACE := gustavofreze/php

PHP_BUILDER_TAG     := $(PHP_NAMESPACE):$(PHP_MINOR)-builder-$(PHP_VERSION)
PHP_RUNTIME_TAG     := $(PHP_NAMESPACE):$(PHP_MINOR)-runtime-$(PHP_VERSION)
PHP_DEVELOPMENT_TAG := $(PHP_NAMESPACE):$(PHP_MINOR)-development-$(PHP_VERSION)
PHP_CLI_TAG         := $(PHP_NAMESPACE):$(PHP_MINOR)-cli-$(PHP_VERSION)

# ---- Python image coordinates -----------------------------------------------
PYTHON_MINOR     := 3.14
PYTHON_VERSION   := $(shell cat images/python/3.14/VERSION)
PYTHON_NAMESPACE := gustavofreze/python

PYTHON_BUILDER_TAG     := $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-builder-$(PYTHON_VERSION)
PYTHON_RUNTIME_TAG     := $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-runtime-$(PYTHON_VERSION)
PYTHON_DEVELOPMENT_TAG := $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-development-$(PYTHON_VERSION)
PYTHON_CLI_TAG         := $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-cli-$(PYTHON_VERSION)

# ---- Publication ------------------------------------------------------------
# Immutable version tags only. Docker Hub is the default registry, override for any other
# (REGISTRY=ghcr.io publishes to the GitHub container registry).
REGISTRY ?= docker.io

# ---- Discovered Dockerfiles (one per build unit, never hardcoded) ------------
DOCKERFILES := $(wildcard images/*/*/Dockerfile)

# ---- Shared smoke library ---------------------------------------------------
# Host-side helpers every family's scripts/smoke sources. Exported so each smoke invocation below
# resolves it by absolute path, never a fragile relative path or an implicit working directory.
SMOKE_LIB := $(CURDIR)/scripts/smoke-lib.sh
export SMOKE_LIB

# ---- Validators (containerized, nothing installed on the host) --------------
# Each pins an exact tool version, coherent with the repository's upstream pin policy.

# Vulnerability scanner: fails on fixable HIGH and CRITICAL findings.
TRIVY_RUN := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v gustavofreze-trivy-cache:/root/.cache/trivy \
    aquasec/trivy:0.71.1 image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1

# Same scanner, plus the accepted findings of the Python family. Scoped to the one family it
# applies to, never repository wide, and each entry in that file carries a justification and a
# revisit condition.
TRIVY_RUN_PYTHON := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v gustavofreze-trivy-cache:/root/.cache/trivy \
    -v $(CURDIR)/images/python/3.14/.trivyignore:/python.trivyignore:ro \
    aquasec/trivy:0.71.1 image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 \
    --ignorefile /python.trivyignore

# Dockerfile linter: reads the Dockerfile on stdin and runs ShellCheck on every RUN body.
HADOLINT_RUN := docker run --rm -i \
    -v $(CURDIR)/.hadolint.yaml:/.hadolint.yaml:ro \
    hadolint/hadolint:v2.12.0-alpine hadolint --config /.hadolint.yaml -

# Image CIS auditor: fails at WARN and above. Every service target is audited with this strict
# runner, so the CIS non-root check (CIS-DI-0001) and the health check requirement (CIS-DI-0006)
# both stay active on it.
DOCKLE_RUN := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn \
    goodwithtech/dockle:v0.4.14 --exit-code 1

# CIS auditor for the base targets that carry no long-running process. It exempts only the health
# check requirement (CIS-DI-0006), per image and nothing else, so every other CIS finding still
# blocks and the non-root check stays active. The exempt targets are the PHP and Python `builder`
# toolchains, discarded in the multi-stage application build, and the Python `runtime`, a language
# base whose consuming application declares the health check for the process it actually runs.
# Revisit an entry here only when that target gains a process of its own to probe.
DOCKLE_RUN_NO_PROCESS := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0006 \
    goodwithtech/dockle:v0.4.14 --exit-code 1

# CIS auditor for the targets that legitimately keep root as the last user. It exempts the non-root
# check (CIS-DI-0001) alongside the health check, per image and nothing else. The exempt targets are
# the PHP and Python `cli` local tooling images: one-shot, no exposed port, root so they can write
# into a bind mount owned by the caller. Revisit an entry here only when tightening that target's
# runtime USER.
DOCKLE_RUN_ROOT := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0001,CIS-DI-0006 \
    goodwithtech/dockle:v0.4.14 --exit-code 1

# One inherited finding, accepted for the Python family only and named here rather than in a
# repository-wide config. The python:alpine base compiles the interpreter and then pins its shared
# library dependencies with `xargs -rt apk add --no-network --virtual .python-rundeps`. Dockle flags
# any `apk add` missing --no-cache (DKL-DI-0004), but --no-network means no index is fetched and no
# cache is written, so there is nothing for --no-cache to remove. The command lives in a base layer
# this repository cannot rewrite, and every `apk add` authored here does pass --no-cache.
# Accepted 2026-08-11. Revisit when the upstream image changes that command.
PYTHON_INHERITED_IGNORES := DKL-DI-0004

DOCKLE_RUN_PYTHON := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0006,$(PYTHON_INHERITED_IGNORES) \
    goodwithtech/dockle:v0.4.14 --exit-code 1

DOCKLE_RUN_PYTHON_ROOT := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0001,CIS-DI-0006,$(PYTHON_INHERITED_IGNORES) \
    goodwithtech/dockle:v0.4.14 --exit-code 1

# Layer-efficiency auditor: non-interactive CI mode against the thresholds in .dive-ci.
DIVE_RUN := docker run --rm -e CI=true \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(CURDIR)/.dive-ci:/.dive-ci:ro \
    wagoodman/dive:v0.13.1 --ci-config /.dive-ci

# =============================================================================
# Targets
# Tag format: ## @section Description  (targets without @ are hidden from help)
# =============================================================================

.PHONY: discover
discover: ## @build List every build unit and the tags it publishes
	@./scripts/discover-images.sh --format=readable

.PHONY: discover-json
discover-json: ## @build Emit the build matrix consumed by the CI and CD workflows
	@./scripts/discover-images.sh --format=json

.PHONY: lint
lint: ## @verify Lint every discovered Dockerfile (ShellCheck on RUN bodies included)
	@for dockerfile in $(DOCKERFILES); do
		echo "[lint] $${dockerfile}"
		$(HADOLINT_RUN) < "$${dockerfile}"
	done

.PHONY: lint-php
lint-php: ## @verify Lint the PHP Dockerfile
	@echo "[lint] images/php/8.5/Dockerfile"
	@$(HADOLINT_RUN) < images/php/8.5/Dockerfile

.PHONY: lint-python
lint-python: ## @verify Lint the Python Dockerfile
	@echo "[lint] images/python/3.14/Dockerfile"
	@$(HADOLINT_RUN) < images/python/3.14/Dockerfile

.PHONY: build
build: build-php build-python ## @build Build every image family

.PHONY: build-php
build-php: ## @build Build the PHP builder, runtime, development, and cli images
	@docker build --target builder     -t $(PHP_BUILDER_TAG)     -t $(PHP_NAMESPACE):$(PHP_MINOR)-builder     images/php/8.5
	@docker build --target runtime     -t $(PHP_RUNTIME_TAG)     -t $(PHP_NAMESPACE):$(PHP_MINOR)-runtime     images/php/8.5
	@docker build --target development -t $(PHP_DEVELOPMENT_TAG) -t $(PHP_NAMESPACE):$(PHP_MINOR)-development images/php/8.5
	@docker build --target cli         -t $(PHP_CLI_TAG)         -t $(PHP_NAMESPACE):$(PHP_MINOR)-cli         images/php/8.5

.PHONY: build-python
build-python: ## @build Build the Python builder, runtime, development, and cli images
	@docker build --target builder     -t $(PYTHON_BUILDER_TAG)     -t $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-builder     images/python/3.14
	@docker build --target runtime     -t $(PYTHON_RUNTIME_TAG)     -t $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-runtime     images/python/3.14
	@docker build --target development -t $(PYTHON_DEVELOPMENT_TAG) -t $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-development images/python/3.14
	@docker build --target cli         -t $(PYTHON_CLI_TAG)         -t $(PYTHON_NAMESPACE):$(PYTHON_MINOR)-cli         images/python/3.14

.PHONY: scan
scan: scan-php scan-python ## @verify Scan every image family for HIGH and CRITICAL vulnerabilities

.PHONY: scan-php
scan-php: ## @verify Scan the PHP images for HIGH and CRITICAL vulnerabilities
	@$(TRIVY_RUN) $(PHP_RUNTIME_TAG)
	@$(TRIVY_RUN) $(PHP_DEVELOPMENT_TAG)
	@$(TRIVY_RUN) $(PHP_BUILDER_TAG)
	@$(TRIVY_RUN) $(PHP_CLI_TAG)

.PHONY: scan-python
scan-python: ## @verify Scan the Python images for HIGH and CRITICAL vulnerabilities
	@# The production runtime carries no installer, so it is scanned with no ignore file at all: a
	@# change that puts pip back into production fails here instead of inheriting an exemption. The
	@# three targets that must carry pip are scanned with the family-scoped accepted findings.
	@$(TRIVY_RUN) $(PYTHON_RUNTIME_TAG)
	@$(TRIVY_RUN_PYTHON) $(PYTHON_DEVELOPMENT_TAG)
	@$(TRIVY_RUN_PYTHON) $(PYTHON_BUILDER_TAG)
	@$(TRIVY_RUN_PYTHON) $(PYTHON_CLI_TAG)

.PHONY: audit
audit: audit-php audit-python ## @verify Audit every image against the CIS Docker Benchmark

.PHONY: audit-php
audit-php: ## @verify Audit the PHP images against the CIS Docker Benchmark
	@# runtime and development are service targets: non-root with a health check, audited strictly.
	@# builder drops to www-data but runs no process, so only the health check is exempt. cli is the
	@# root tooling image, audited with both exemptions.
	@$(DOCKLE_RUN) $(PHP_RUNTIME_TAG)
	@$(DOCKLE_RUN) $(PHP_DEVELOPMENT_TAG)
	@$(DOCKLE_RUN_NO_PROCESS) $(PHP_BUILDER_TAG)
	@$(DOCKLE_RUN_ROOT) $(PHP_CLI_TAG)

.PHONY: audit-python
audit-python: ## @verify Audit the Python images against the CIS Docker Benchmark
	@# No Python target starts a process of its own, so the health check is exempt on all of them.
	@# runtime, development, and builder still drop to the app user and are audited non-root. cli is
	@# the root tooling image, audited with both exemptions.
	@$(DOCKLE_RUN_PYTHON) $(PYTHON_RUNTIME_TAG)
	@$(DOCKLE_RUN_PYTHON) $(PYTHON_DEVELOPMENT_TAG)
	@$(DOCKLE_RUN_PYTHON) $(PYTHON_BUILDER_TAG)
	@$(DOCKLE_RUN_PYTHON_ROOT) $(PYTHON_CLI_TAG)

.PHONY: efficiency
efficiency: efficiency-php efficiency-python ## @verify Check the layer efficiency of every image

.PHONY: efficiency-php
efficiency-php: ## @verify Check the layer efficiency of the PHP images
	@$(DIVE_RUN) $(PHP_RUNTIME_TAG)
	@$(DIVE_RUN) $(PHP_DEVELOPMENT_TAG)
	@$(DIVE_RUN) $(PHP_BUILDER_TAG)
	@$(DIVE_RUN) $(PHP_CLI_TAG)

.PHONY: efficiency-python
efficiency-python: ## @verify Check the layer efficiency of the Python images
	@$(DIVE_RUN) $(PYTHON_RUNTIME_TAG)
	@$(DIVE_RUN) $(PYTHON_DEVELOPMENT_TAG)
	@$(DIVE_RUN) $(PYTHON_BUILDER_TAG)
	@$(DIVE_RUN) $(PYTHON_CLI_TAG)

.PHONY: smoke
smoke: smoke-php smoke-python ## @verify Boot throwaway containers and assert the runtime contract

.PHONY: smoke-php
smoke-php: ## @verify Boot throwaway PHP containers and assert the runtime contract
	@bash images/php/8.5/scripts/smoke $(PHP_RUNTIME_TAG) $(PHP_DEVELOPMENT_TAG) $(PHP_BUILDER_TAG) $(PHP_CLI_TAG)

.PHONY: smoke-python
smoke-python: ## @verify Boot throwaway Python containers and assert the runtime contract
	@bash images/python/3.14/scripts/smoke $(PYTHON_RUNTIME_TAG) $(PYTHON_DEVELOPMENT_TAG) $(PYTHON_BUILDER_TAG) $(PYTHON_CLI_TAG)

.PHONY: review
review: lint build scan audit efficiency smoke ## @verify Full local gate: lint, build, scan, audit, efficiency, smoke

.PHONY: review-php
review-php: lint-php build-php scan-php audit-php efficiency-php smoke-php ## @verify Full gate scoped to the PHP family

.PHONY: review-python
review-python: lint-python build-python scan-python audit-python efficiency-python smoke-python ## @verify Full gate scoped to the Python family

.PHONY: verify
verify: review ## @verify Alias of review: run the full local gate

# Publication is gated by the review chain as a make dependency, not by convention: each
# publish-<family> lists review-<family> as a prerequisite, so a push only happens after lint,
# build, scan, audit, efficiency, and smoke all passed for the family being published. Only the
# immutable versioned tags are pushed. The floating aliases are local convenience and the CD
# workflow owns their publication.
.PHONY: publish
publish: publish-php publish-python ## @publish Push every family's versioned tags to REGISTRY, each gated by its review chain

.PHONY: publish-php
publish-php: review-php ## @publish Push the versioned PHP tags to REGISTRY, gated by review-php
	@for tag in $(PHP_BUILDER_TAG) $(PHP_RUNTIME_TAG) $(PHP_DEVELOPMENT_TAG) $(PHP_CLI_TAG); do
		docker tag "$${tag}" "$(REGISTRY)/$${tag}"
		docker push "$(REGISTRY)/$${tag}"
	done

.PHONY: publish-python
publish-python: review-python ## @publish Push the versioned Python tags to REGISTRY, gated by review-python
	@for tag in $(PYTHON_BUILDER_TAG) $(PYTHON_RUNTIME_TAG) $(PYTHON_DEVELOPMENT_TAG) $(PYTHON_CLI_TAG); do
		docker tag "$${tag}" "$(REGISTRY)/$${tag}"
		docker push "$(REGISTRY)/$${tag}"
	done

.PHONY: help
help: ## @help Display this help message
	@echo "Usage: make [target]"
	@echo ""
	@awk 'BEGIN { \
		FS = ":.*?## @"; \
		section_order[1]="build"; \
		section_order[2]="verify"; \
		section_order[3]="publish"; \
		section_order[4]="help"; \
		section_title["build"]="Build"; \
		section_title["verify"]="Verification"; \
		section_title["publish"]="Publication"; \
		section_title["help"]="Help"; \
	} \
	/^[a-zA-Z0-9_-]+:.*## @/ { \
		split($$2, parts, " "); \
		section = parts[1]; \
		desc = substr($$2, length(section) + 2); \
		targets[section] = targets[section] sprintf("  \033[36m%-32s\033[0m %s\n", $$1, desc); \
	} \
	END { \
		for (i = 1; i <= 4; i++) { \
			s = section_order[i]; \
			if (targets[s]) { \
				printf "\033[1m%s\033[0m\n%s\n", section_title[s], targets[s]; \
			} \
		} \
	}' $(MAKEFILE_LIST)
