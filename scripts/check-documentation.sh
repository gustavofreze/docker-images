#!/usr/bin/env bash
set -euo pipefail

# check-documentation.sh: Asserts the family READMEs agree with the build units they describe.
#
# Those READMEs are pasted verbatim into the Docker Hub overview, so a stale tag there tells a consumer
# to pin a version that is no longer current. Nothing else compares them against the source, and a
# version bump touches many more lines of prose than of build input.
#
# The checks read tokens rather than table positions, because the same tag appears bare in a table, in
# a fenced Dockerfile snippet and inside a shell command, and a version bump has to move all of them.
#
# Usage: check-documentation.sh
#
# Arguments:
#   None. Runs from the repository root and checks every family it finds.

readonly IMAGES_DIRECTORY="images"

report() {
    local message="${1:?Usage: report <message>}"

    echo "[docs] ${message}" >&2
}

read_version() {
    local unit="${1:?Usage: read_version <build unit>}"

    [[ -f "${unit}/VERSION" ]] || return 1
    tr -d '[:space:]' < "${unit}/VERSION"
}

read_upstream_pins() {
    local family="${1:?Usage: read_upstream_pins <family>}"

    grep -hoE '^FROM[[:space:]]+\S+' "${IMAGES_DIRECTORY}/${family}"/*/Dockerfile \
        | awk '{print $2}' \
        | sort -u
}

check_tags() {
    local readme="${1:?Usage: check_tags <readme>}"
    local family="${2:?Usage: check_tags <readme> <family>}"
    local failures=0
    local tag minor version expected

    while IFS= read -r tag; do
        version="${tag##*-}"
        minor="${tag%-*}"
        minor="${minor%-*}"

        expected="$(read_version "${IMAGES_DIRECTORY}/${family}/${minor}")" || {
            report "${readme}: names ${tag}, and ${minor} is not a build unit of ${family}"
            failures=1
            continue
        }

        [[ "${version}" == "${expected}" ]] && continue

        report "${readme}: ${tag} names version ${version}, but ${minor} is at ${expected}"
        failures=1
    done < <(
        grep -oE '[0-9]+\.[0-9]+-(builder|cli|runtime|development)-[0-9]+\.[0-9]+\.[0-9]+' "${readme}" \
            | sort -u
    )

    return "${failures}"
}

check_upstream_pins() {
    local readme="${1:?Usage: check_upstream_pins <readme>}"
    local family="${2:?Usage: check_upstream_pins <readme> <family>}"
    local failures=0
    local pins declared

    # A literal backtick, so the pattern below stays out of single quotes. ShellCheck reads a backtick
    # inside single quotes as a command substitution someone forgot to make expandable.
    local backtick=$'\x60'

    pins="$(read_upstream_pins "${family}")"

    while IFS= read -r declared; do
        grep -qxF "${declared}" <<< "${pins}" && continue

        report "${readme}: names the upstream pin ${declared}, which no Dockerfile of ${family} uses"
        failures=1
    done < <(
        grep -oE "${backtick}[a-z]+:[0-9]+\.[0-9]+\.[0-9]+[a-z0-9.-]*${backtick}" "${readme}" \
            | tr -d "${backtick}" \
            | sort -u
    )

    return "${failures}"
}

check_family() {
    local readme="${1:?Usage: check_family <readme>}"
    local family
    local failures=0

    family="$(basename "$(dirname "${readme}")")"
    report "checking ${readme}"

    check_tags "${readme}" "${family}" || failures=1
    check_upstream_pins "${readme}" "${family}" || failures=1

    return "${failures}"
}

main() {
    local readme
    local failures=0

    [[ -d "${IMAGES_DIRECTORY}" ]] || {
        report "run this from the repository root, ${IMAGES_DIRECTORY} not found"
        exit 1
    }

    while IFS= read -r readme; do
        check_family "${readme}" || failures=1
    done < <(find "${IMAGES_DIRECTORY}" -mindepth 2 -maxdepth 2 -name README.md | sort)

    [[ "${failures}" -eq 0 ]] || {
        report "documentation disagrees with the build units above"
        exit 1
    }

    report "every family README agrees with its build units"
}

main "$@"
