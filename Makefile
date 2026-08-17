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

# ---- Publication (REGISTRY=ghcr.io for the GitHub registry) -----------------
REGISTRY ?= docker.io

# ---- Discovered Dockerfiles (one per build unit, never hardcoded) ------------
DOCKERFILES := $(wildcard images/*/*/Dockerfile)

# ---- Discovered shell scripts (found by shebang, so an extensionless one counts)
SHELL_SCRIPTS := $(shell grep -rl '^#!/usr/bin/env bash' scripts images | sort)

# ---- Shared smoke library ---------------------------------------------------
SMOKE_LIB := $(CURDIR)/scripts/smoke-lib.sh
export SMOKE_LIB

# ---- Validator images -------------------------------------------------------
# Read from docker-compose.yml so the version lives in exactly one place, and that place is an
# ecosystem Dependabot understands. Hardcoding a tag here would put it outside every updater.
TOOLS_COMPOSE := docker-compose.yml

# The search stops at the next service key, so a service missing its own image: line resolves to
# nothing and trips the guard below. Without that bound the scan walks into the next block and returns
# a different tool's image, which is worse than an error: the gate would run the wrong validator.
tool_image = $(shell awk -v service="$(1):" \
    '$$1==service{found=1; next} found&&/^    [^ ]/{exit} found&&$$1=="image:"{print $$2; exit}' \
    $(TOOLS_COMPOSE))

DIVE_IMAGE       := $(call tool_image,dive)
GRYPE_IMAGE      := $(call tool_image,grype)
TRIVY_IMAGE      := $(call tool_image,trivy)
DOCKLE_IMAGE     := $(call tool_image,dockle)
HADOLINT_IMAGE   := $(call tool_image,hadolint)
SHELLCHECK_IMAGE := $(call tool_image,shellcheck)

# A silently empty image would turn `docker run` into a confusing failure deep inside a gate stage.
$(foreach v,DIVE_IMAGE GRYPE_IMAGE TRIVY_IMAGE DOCKLE_IMAGE HADOLINT_IMAGE SHELLCHECK_IMAGE,\
  $(if $($(v)),,$(error $(v) not found in $(TOOLS_COMPOSE))))

# ---- Validators (containerized, nothing installed on the host) ---------------
# The DOCKLE variants differ only in the CIS checks they exempt, which their DOCKLE_IGNORES lines
# name. Why each exemption is allowed lives in the docker-images rule, section Where the reasoning
# lives.

# A scan reads only the documents that describe the image in front of it, so both are per family and
# each is passed only to the family it was written for. Another family's VEX would be inert, because a
# statement is scoped to its product purl, but it would still be a claim about an image it does not
# describe. Another family's gate policy would be worse: a repository-wide exemption wearing a local
# name. A family with no document expands to nothing and scans bare, which is the safe direction.
vex_flag     = $(if $(wildcard vex/$(1).openvex.json),--vex /vex/$(1).openvex.json)
grype_policy = $(if $(wildcard .grype/$(1).yaml),-v $(CURDIR)/.grype/$(1).yaml:/policy.yaml:ro -e GRYPE_CONFIG=/policy.yaml)
trivy_policy = $(if $(wildcard .trivy/$(1).yaml),-v $(CURDIR)/.trivy/$(1).yaml:/policy.yaml:ro)
trivy_flag   = $(if $(wildcard .trivy/$(1).yaml),--ignorefile /policy.yaml)

# Two scanners on purpose. Trivy reads the distro security database, Grype cross-references upstream
# advisories and Go module data, and neither is a superset of the other: Grype caught a HIGH in the
# Go stdlib of a vendored binary that Trivy reported clean. A single scanner is not coverage.
GRYPE_RUN = docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v gustavofreze-grype-cache:/root/.cache/grype \
    -v $(CURDIR)/vex:/vex:ro \
    $(call grype_policy,$(1)) \
    $(GRYPE_IMAGE) --only-fixed --fail-on high $(call vex_flag,$(1))

TRIVY_RUN = docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v gustavofreze-trivy-cache:/root/.cache/trivy \
    -v $(CURDIR)/vex:/vex:ro \
    $(call trivy_policy,$(1)) \
    $(TRIVY_IMAGE) image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 \
    $(call vex_flag,$(1)) $(call trivy_flag,$(1))

# The one scan that reads nothing at all. Its single caller is the Python runtime, in scan-python.
TRIVY_RUN_BARE := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v gustavofreze-trivy-cache:/root/.cache/trivy \
    $(TRIVY_IMAGE) image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1

HADOLINT_RUN := docker run --rm -i \
    -v $(CURDIR)/.hadolint.yaml:/.hadolint.yaml:ro \
    $(HADOLINT_IMAGE) hadolint --config /.hadolint.yaml -

# hadolint shell-checks the RUN bodies, this covers the standalone scripts the shell-scripts rule
# governs. No severity floor: the scripts are clean at ShellCheck's strictest, which is what makes
# the quoting and cd-guard items of that rule enforced rather than aspirational. --external-sources
# follows the `shellcheck source=` directives into the shared smoke library.
SHELLCHECK_RUN := docker run --rm \
    -v $(CURDIR):/mnt:ro -w /mnt \
    $(SHELLCHECK_IMAGE) --external-sources

DOCKLE_RUN := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn \
    $(DOCKLE_IMAGE) --exit-code 1

DOCKLE_RUN_NO_PROCESS := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0006 \
    $(DOCKLE_IMAGE) --exit-code 1

DOCKLE_RUN_ROOT := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0001,CIS-DI-0006 \
    $(DOCKLE_IMAGE) --exit-code 1

# One inherited finding, accepted for the Python family only. The python:alpine base pins the shared
# libraries of the interpreter it just compiled with `xargs -rt apk add --no-network --virtual
# .python-rundeps`. Dockle flags any `apk add` missing --no-cache (DKL-DI-0004), but --no-network
# fetches no index and writes no cache, so there is nothing to remove. It lives in a base layer this
# repository cannot rewrite, and every `apk add` authored here does pass --no-cache.
# Accepted 2026-08-11. Revisit when the upstream image changes that command.
PYTHON_INHERITED_IGNORES := DKL-DI-0004

DOCKLE_RUN_PYTHON := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0006,$(PYTHON_INHERITED_IGNORES) \
    $(DOCKLE_IMAGE) --exit-code 1

DOCKLE_RUN_PYTHON_ROOT := docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w / -e DOCKLE_EXIT_LEVEL=warn -e DOCKLE_IGNORES=CIS-DI-0001,CIS-DI-0006,$(PYTHON_INHERITED_IGNORES) \
    $(DOCKLE_IMAGE) --exit-code 1

DIVE_RUN := docker run --rm -e CI=true \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(CURDIR)/.dive-ci:/.dive-ci:ro \
    $(DIVE_IMAGE) --ci-config /.dive-ci

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
lint: lint-scripts lint-docs ## @verify Lint every Dockerfile, shell script, and family README
	@for dockerfile in $(DOCKERFILES); do
		echo "[lint] $${dockerfile}"
		$(HADOLINT_RUN) < "$${dockerfile}"
	done

.PHONY: lint-docs
lint-docs: ## @verify Assert every family README agrees with its build units
	@./scripts/check-documentation.sh

.PHONY: lint-scripts
lint-scripts: ## @verify ShellCheck every discovered shell script
	@for script in $(SHELL_SCRIPTS); do
		echo "[lint] $${script}"
	done
	@$(SHELLCHECK_RUN) $(SHELL_SCRIPTS)

# Each family-scoped lint pulls in lint-scripts, because the workflows run review-<family> and never
# the aggregate. Without it ShellCheck would run only on a developer machine, which is the opposite of
# a gate. lint-scripts is .PHONY and make runs it once per invocation, so the full review does not
# repeat it.
.PHONY: lint-php
lint-php: lint-scripts lint-docs ## @verify Lint the PHP Dockerfile, every shell script, and the READMEs
	@echo "[lint] images/php/8.5/Dockerfile"
	@$(HADOLINT_RUN) < images/php/8.5/Dockerfile

.PHONY: lint-python
lint-python: lint-scripts lint-docs ## @verify Lint the Python Dockerfile, every shell script, and the READMEs
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
	@for tag in $(PHP_RUNTIME_TAG) $(PHP_DEVELOPMENT_TAG) $(PHP_BUILDER_TAG) $(PHP_CLI_TAG); do
		echo "[scan] $${tag}"
		$(call TRIVY_RUN,php) "$${tag}"
		$(call GRYPE_RUN,php) "$${tag}"
	done

.PHONY: scan-python
scan-python: ## @verify Scan the Python images for HIGH and CRITICAL vulnerabilities
	@# The runtime carries no installer, so Trivy scans it with no VEX at all. Every statement the VEX would have
	@# suppressed covers a package pip vendors, so putting pip back into production fails here rather than inheriting
	@# an exemption.
	@echo "[scan] $(PYTHON_RUNTIME_TAG)"
	@$(TRIVY_RUN_BARE) $(PYTHON_RUNTIME_TAG)
	@$(call GRYPE_RUN,python) $(PYTHON_RUNTIME_TAG)
	@for tag in $(PYTHON_DEVELOPMENT_TAG) $(PYTHON_BUILDER_TAG) $(PYTHON_CLI_TAG); do
		echo "[scan] $${tag}"
		$(call TRIVY_RUN,python) "$${tag}"
		$(call GRYPE_RUN,python) "$${tag}"
	done

.PHONY: audit
audit: audit-php audit-python ## @verify Audit every image against the CIS Docker Benchmark

.PHONY: audit-php
audit-php: ## @verify Audit the PHP images against the CIS Docker Benchmark
	@$(DOCKLE_RUN) $(PHP_RUNTIME_TAG)
	@$(DOCKLE_RUN) $(PHP_DEVELOPMENT_TAG)
	@$(DOCKLE_RUN_NO_PROCESS) $(PHP_BUILDER_TAG)
	@$(DOCKLE_RUN_ROOT) $(PHP_CLI_TAG)

.PHONY: audit-python
audit-python: ## @verify Audit the Python images against the CIS Docker Benchmark
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

# Gated by the review chain as a make dependency, not by convention: each publish-<family> lists
# review-<family> as a prerequisite, so a push cannot happen before that family passed the gate. Only
# the immutable versioned tags go out here, the CD workflow owns the floating aliases.
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
