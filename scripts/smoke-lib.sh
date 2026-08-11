#!/usr/bin/env bash

# smoke-lib.sh: Shared host-side helpers for the family smoke scripts, sourced through the SMOKE_LIB
# path the Makefile exports. Only defines functions and is sourced, never executed, so it carries no
# `set -euo pipefail` and no `main`: the sourcing script owns both.
#
# Usage: source "${SMOKE_LIB:?SMOKE_LIB not set}"

# shellcheck shell=bash

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

# assert_absent is the image-level counterpart of assert_missing below, for targets with no
# long-running process and therefore no booted container to exec into.
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

# Tolerates an absent container, so it is safe both in an EXIT trap and before booting a fresh one.
cleanup() {
    local container_name="${1:?Usage: cleanup <container>}"

    docker rm -f "${container_name}" > /dev/null 2>&1 || true
}

# Polls a caller-supplied probe function until it succeeds or the attempts run out, so each family
# keeps its own readiness check while sharing this loop and its failure diagnostics.
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
