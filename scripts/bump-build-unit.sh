#!/usr/bin/env bash
set -euo pipefail

# bump-build-unit.sh: Advances the patch version of a build unit and moves its documented tags and
# upstream pins with it.
#
# A version bump is never one file. VERSION carries the number, and the family README names the full
# tag in a table, in a fenced Dockerfile snippet and inside shell commands, and the upstream pin in
# prose, all of which the lint stage compares against the unit. Missing one of them is exactly what
# the documentation check exists to catch, so an automated bump makes the same edit that check demands.
#
# A tag is found by the version at its end rather than by a list of target names. The vocabulary of
# published targets already lives in discover-images.sh and in check-documentation.sh, and a third
# copy here would be one more place for it to drift.
#
# Usage: bump-build-unit.sh <build unit>
#
# Arguments:
#   build unit  Path of the unit to bump, images/<family>/<upstream-minor>.

report() {
    local message="${1:?Usage: report <message>}"

    echo "[bump] ${message}" >&2
}

next_version() {
    local current="${1:?Usage: next_version <version>}"
    local major minor patch

    IFS=. read -r major minor patch <<< "${current}"

    printf '%s.%s.%s' "${major}" "${minor}" "$((patch + 1))"
}

retag_readme() {
    local readme="${1:?Usage: retag_readme <readme> <upstream-minor> <current> <next>}"
    local upstream_minor="${2:?Usage: retag_readme <readme> <upstream-minor> <current> <next>}"
    local current="${3:?Usage: retag_readme <readme> <upstream-minor> <current> <next>}"
    local next="${4:?Usage: retag_readme <readme> <upstream-minor> <current> <next>}"

    [[ -f "${readme}" ]] || return 0

    sed -E -i \
        "s/(${upstream_minor//./\\.}-[a-z-]+)-${current//./\\.}/\1-${next}/g" \
        "${readme}"
}

repin_readme() {
    local readme="${1:?Usage: repin_readme <readme> <dockerfile>}"
    local dockerfile="${2:?Usage: repin_readme <readme> <dockerfile>}"
    local backtick=$'\x60'
    local pin prefix

    [[ -f "${readme}" ]] || return 0

    while IFS= read -r pin; do
        prefix="$(grep -oE '^[a-z]+:[0-9]+\.[0-9]+\.' <<< "${pin}")" || continue

        sed -E -i \
            "s/${backtick}${prefix//./\\.}[a-z0-9.-]+${backtick}/${backtick}${pin}${backtick}/g" \
            "${readme}"
    done < <(grep -oE '^FROM[[:space:]]+\S+' "${dockerfile}" | awk '{print $2}' | sort -u)
}

main() {
    local unit="${1:?Usage: bump-build-unit.sh <build unit>}"
    local current next family upstream_minor

    [[ -f "${unit}/VERSION" ]] || {
        report "${unit} is not a build unit, it carries no VERSION"
        exit 1
    }

    current="$(tr -d '[:space:]' < "${unit}/VERSION")"
    next="$(next_version "${current}")"
    family="$(basename "$(dirname "${unit}")")"
    upstream_minor="$(basename "${unit}")"

    printf '%s\n' "${next}" > "${unit}/VERSION"
    retag_readme "images/${family}/README.md" "${upstream_minor}" "${current}" "${next}"
    repin_readme "images/${family}/README.md" "${unit}/Dockerfile"

    report "${unit} moved from ${current} to ${next}"
    echo "${next}"
}

main "$@"
