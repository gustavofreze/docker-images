#!/usr/bin/env bash

# smoke-lib.sh: Shared host-side helpers for the family smoke scripts. Every
# images/**/scripts/smoke sources this through the SMOKE_LIB path the Makefile exports. The smoke
# scripts run on the host and reach into throwaway containers with docker exec and docker inspect,
# so these helpers centralize the assertion, cleanup, wait, and logging idioms that every family
# would otherwise duplicate. This file only defines functions and is sourced, never executed, so it
# carries no `set -euo pipefail` and no `main` (the sourcing script owns both).
#
# Usage: source "${SMOKE_LIB:?SMOKE_LIB not set}"

# shellcheck shell=bash

# Logging: the single home for the [smoke] idiom. Passing assertions go to stdout, failures to
# stderr, so a caller can separate the two streams.
smoke_ok() {
    local label="${1:?Usage: smoke_ok <label>}"

    echo "[smoke] ok: ${label}"
}

smoke_fail() {
    local label="${1:?Usage: smoke_fail <label>}"

    echo "[smoke] failed: ${label}" >&2
}

assert_contains() {
    local expected="${1:?Usage: assert_contains <expected> <actual> <label>}"
    local actual="${2:?Usage: assert_contains <expected> <actual> <label>}"
    local label="${3:?Usage: assert_contains <expected> <actual> <label>}"

    if [[ "${actual}" == *"${expected}"* ]]; then
        smoke_ok "${label}"
        return 0
    fi

    smoke_fail "${label} (expected '${expected}', got '${actual}')"
    return 1
}

assert_not_contains() {
    local forbidden="${1:?Usage: assert_not_contains <forbidden> <actual> <label>}"
    local actual="${2:?Usage: assert_not_contains <forbidden> <actual> <label>}"
    local label="${3:?Usage: assert_not_contains <forbidden> <actual> <label>}"

    if [[ "${actual}" != *"${forbidden}"* ]]; then
        smoke_ok "${label}"
        return 0
    fi

    smoke_fail "${label} ('${forbidden}' is present)"
    return 1
}

# assert_absent: Asserts a command is not resolvable inside an image, running the check in a
# throwaway container with the base entrypoint cleared. Used for the targets with no long-running
# process, where there is no container to exec into.
assert_absent() {
    local image="${1:?Usage: assert_absent <image> <command> <label>}"
    local command_name="${2:?Usage: assert_absent <image> <command> <label>}"
    local label="${3:?Usage: assert_absent <image> <command> <label>}"

    if ! docker run --rm --entrypoint "" "${image}" which "${command_name}" > /dev/null 2>&1; then
        smoke_ok "${label}"
        return 0
    fi

    smoke_fail "${label} ('${command_name}' is present)"
    return 1
}

assert_missing() {
    local container_name="${1:?Usage: assert_missing <container> <command> <label>}"
    local command_name="${2:?Usage: assert_missing <container> <command> <label>}"
    local label="${3:?Usage: assert_missing <container> <command> <label>}"

    if ! docker exec "${container_name}" which "${command_name}" > /dev/null 2>&1; then
        smoke_ok "${label}"
        return 0
    fi

    smoke_fail "${label} ('${command_name}' is present)"
    return 1
}

assert_module_absent() {
    local container_name="${1:?Usage: assert_module_absent <container> <module> <label>}"
    local module_name="${2:?Usage: assert_module_absent <container> <module> <label>}"
    local label="${3:?Usage: assert_module_absent <container> <module> <label>}"

    if ! docker exec "${container_name}" php -m | grep -qi "${module_name}"; then
        smoke_ok "${label}"
        return 0
    fi

    smoke_fail "${label} ('${module_name}' is loaded)"
    return 1
}

# cleanup: Removes the named throwaway container, tolerating its absence, so it is safe both in an
# EXIT trap and before booting a fresh container.
cleanup() {
    local container_name="${1:?Usage: cleanup <container>}"

    docker rm -f "${container_name}" > /dev/null 2>&1 || true
}

# wait_until: Polls a caller-supplied probe function until it succeeds or the attempts run out. The
# probe is a function name that returns zero when the container is ready, so each family keeps its
# own readiness check (a reported health status, an accepted connection) while sharing this loop,
# the success line, and the failure diagnostics.
#
# Usage: wait_until <container> <description> <attempts> <interval-seconds> <probe-function>
wait_until() {
    local container_name="${1:?Usage: wait_until <container> <description> <attempts> <interval> <probe>}"
    local description="${2:?Usage: wait_until <container> <description> <attempts> <interval> <probe>}"
    local attempts="${3:?Usage: wait_until <container> <description> <attempts> <interval> <probe>}"
    local interval="${4:?Usage: wait_until <container> <description> <attempts> <interval> <probe>}"
    local probe="${5:?Usage: wait_until <container> <description> <attempts> <interval> <probe>}"

    local count=0
    while (( count < attempts )); do
        if "${probe}"; then
            smoke_ok "${description}"
            return 0
        fi
        count=$((count + 1))
        sleep "${interval}"
    done

    smoke_fail "${description} (gave up after ${attempts} attempts)"
    docker logs "${container_name}" >&2
    return 1
}
