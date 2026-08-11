#!/usr/bin/env bash
set -euo pipefail

# discover-images.sh: Enumerates every build unit under images/ and the tags it publishes.
#
# A build unit is a directory images/<family>/<upstream-minor>/ holding one multi-target Dockerfile
# and a VERSION file. Each build target declared in that Dockerfile becomes one entry, carrying the
# immutable versioned tag and the floating alias that tracks it. This script is the single source
# the CI and CD workflows build their matrix from, so the workflows never restate the target list.
#
# Usage: discover-images.sh [--format=json|families|readable]
#
# Arguments:
#   --format=json      One JSON object per target, the matrix the workflows consume (default).
#   --format=families  JSON array of family names, the matrix the gate workflow consumes.
#   --format=readable  Human-readable table, what `make discover` prints.

readonly IMAGES_DIRECTORY="images"

format_json() {
    local entries=("$@")

    printf '[%s]\n' "$(join_with_comma "${entries[@]}")"
}

join_with_comma() {
    local separator=""
    local item

    for item in "$@"; do
        printf '%s%s' "${separator}" "${item}"
        separator=","
    done
}

# read_targets: Prints one build target name per line, in declaration order, for the Dockerfile
# given. A target is a named build stage, so the closed stage vocabulary of the repository is read
# straight from the file instead of being restated here.
read_targets() {
    local dockerfile="${1:?Usage: read_targets <dockerfile>}"

    grep -oE '^FROM[[:space:]]+.*[[:space:]]+AS[[:space:]]+[A-Za-z0-9_.-]+' "${dockerfile}" \
        | awk '{print $NF}'
}

# build_entries: Walks every build unit and emits one JSON object per target on its own line. The
# caller decides how to render them, so the walk itself lives in one place.
build_entries() {
    local dockerfile context family minor version target

    while IFS= read -r dockerfile; do
        context="${dockerfile%/Dockerfile}"
        family="$(basename "$(dirname "${context}")")"
        minor="$(basename "${context}")"

        if [[ ! -f "${context}/VERSION" ]]; then
            echo "Error: ${context} has no VERSION file" >&2
            exit 1
        fi

        version="$(tr -d '[:space:]' < "${context}/VERSION")"

        if [[ -z "${version}" ]]; then
            echo "Error: ${context}/VERSION is empty" >&2
            exit 1
        fi

        while IFS= read -r target; do
            printf '{"context":"%s","family":"%s","minor":"%s","target":"%s","version":"%s","tag":"%s-%s-%s","alias":"%s-%s"}\n' \
                "${context}" "${family}" "${minor}" "${target}" "${version}" \
                "${minor}" "${target}" "${version}" \
                "${minor}" "${target}"
        done < <(read_targets "${dockerfile}")
    done < <(find "${IMAGES_DIRECTORY}" -mindepth 3 -maxdepth 3 -name Dockerfile -type f | sort)
}

build_families() {
    local entries=("$@")
    local families=()
    local entry family

    for entry in "${entries[@]}"; do
        family="$(printf '%s' "${entry}" | sed -E 's/.*"family":"([^"]+)".*/\1/')"

        case " ${families[*]-} " in
            *" \"${family}\" "*)
                continue
                ;;
        esac

        families+=("\"${family}\"")
    done

    printf '[%s]\n' "$(join_with_comma "${families[@]}")"
}

format_readable() {
    local entries=("$@")
    local entry

    printf '%-22s %-14s %-30s %s\n' "BUILD UNIT" "TARGET" "TAG" "ALIAS"

    for entry in "${entries[@]}"; do
        printf '%s\n' "${entry}" \
            | sed -E 's/.*"context":"([^"]+)".*"family":"([^"]+)".*"target":"([^"]+)".*"tag":"([^"]+)","alias":"([^"]+)".*/\1|\3|\2:\4|\2:\5/' \
            | awk -F'|' '{printf "%-22s %-14s %-30s %s\n", $1, $2, $3, $4}'
    done
}

main() {
    local format="json"
    local argument
    local entries=()

    for argument in "$@"; do
        case "${argument}" in
            --format=*)
                format="${argument#*=}"
                ;;
            *)
                echo "Error: unknown argument '${argument}'. Usage: discover-images.sh [--format=json|families|readable]" >&2
                exit 1
                ;;
        esac
    done

    case "${format}" in
        json|families|readable) ;;
        *)
            echo "Error: invalid format '${format}'. Use 'json', 'families', or 'readable'." >&2
            exit 1
            ;;
    esac

    if [[ ! -d "${IMAGES_DIRECTORY}" ]]; then
        echo "Error: directory '${IMAGES_DIRECTORY}' not found. Run this from the repository root." >&2
        exit 1
    fi

    mapfile -t entries < <(build_entries)

    if [[ ${#entries[@]} -eq 0 ]]; then
        echo "Error: no build unit found under '${IMAGES_DIRECTORY}'" >&2
        exit 1
    fi

    case "${format}" in
        json)
            format_json "${entries[@]}"
            ;;
        families)
            build_families "${entries[@]}"
            ;;
        readable)
            format_readable "${entries[@]}"
            ;;
    esac
}

main "$@"
