#!/usr/bin/env bash
set -euo pipefail

# discover-images.sh: Enumerates every build unit under images/ and the tags it publishes.
#
# A build unit is a directory images/<family>/<upstream-minor>/ holding one multi-target Dockerfile
# and a VERSION file, and each build target in it becomes one entry. This is the single source the CI
# and CD workflows build their matrix from, so the workflows never restate the target list.
#
# Usage: discover-images.sh [--format=json|families|readable]
#
# Arguments:
#   --format=json      One JSON object per target, the matrix the workflows consume (default).
#   --format=families  JSON array of family names, the matrix the gate workflow consumes.
#   --format=readable  Human-readable table, what `make discover` prints.

readonly IMAGES_DIRECTORY="images"

# The closed stage vocabulary of the docker-images rule. A Dockerfile may name any other stage it
# needs, for a pinned upstream binary it copies from, and that stage is deliberately not a target: it
# publishes no tag. Without this list every helper stage would become one.
readonly PUBLISHED_TARGETS="builder cli runtime development"

join_with_comma() {
    local separator=""
    local item

    for item in "$@"; do
        printf '%s%s' "${separator}" "${item}"
        separator=","
    done
}

is_published_target() {
    local candidate="${1:?Usage: is_published_target <stage>}"

    case " ${PUBLISHED_TARGETS} " in
        *" ${candidate} "*)
            return 0
            ;;
    esac

    return 1
}

read_targets() {
    local dockerfile="${1:?Usage: read_targets <dockerfile>}"
    local stage

    while IFS= read -r stage; do
        is_published_target "${stage}" || continue
        printf '%s\n' "${stage}"
    done < <(
        grep -oE '^FROM[[:space:]]+.*[[:space:]]+AS[[:space:]]+[A-Za-z0-9_.-]+' "${dockerfile}" \
            | awk '{print $NF}'
    )
}

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

format_json() {
    local entries=("$@")

    printf '[%s]\n' "$(join_with_comma "${entries[@]}")"
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

# Reads the target list straight out of the named build stages, so it is never restated here.
# Emits one JSON object per target on its own line. The caller decides how to render them.
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
