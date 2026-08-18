#!/usr/bin/env bash
set -euo pipefail

# changed-build-units.sh: Prints every build unit a commit range touches, one path per line.
#
# A build unit is a directory images/<family>/<upstream-minor>/ carrying a VERSION file. A path deep
# enough to look like one but holding no VERSION file is not a build unit and is left out, so every
# line a caller reads is something with a version to check or to move. This is the single source both
# the version guard and the automated bump read, so the two never disagree about what changed.
#
# Usage: changed-build-units.sh <base-sha> <head-sha>
#
# Arguments:
#   base-sha  The commit the range starts at, exclusive.
#   head-sha  The commit the range ends at, inclusive.

readonly UNIT_PATHSPEC="images/*/*/**"

changed_paths() {
    local base="${1:?Usage: changed_paths <base-sha> <head-sha>}"
    local head="${2:?Usage: changed_paths <base-sha> <head-sha>}"

    git diff --name-only "${base}" "${head}" -- "${UNIT_PATHSPEC}" \
        | awk -F/ 'NF >= 4 {print $1"/"$2"/"$3}' \
        | sort -u
}

main() {
    local base="${1:?Usage: changed-build-units.sh <base-sha> <head-sha>}"
    local head="${2:?Usage: changed-build-units.sh <base-sha> <head-sha>}"
    local unit

    while read -r unit; do
        [[ -f "${unit}/VERSION" ]] || continue

        echo "${unit}"
    done < <(changed_paths "${base}" "${head}")
}

main "$@"
