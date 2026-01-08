#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly RESET='\033[0m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR
DISCOVER_SCRIPT="${SCRIPTS_DIR}/discover-images.sh"
readonly DISCOVER_SCRIPT

check_dependencies() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required. Please install it first." >&2
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        echo "Error: docker is required." >&2
        exit 1
    fi
}

main() {
    check_dependencies

    echo "Building Docker images..."

    chmod +x "${DISCOVER_SCRIPT}"

    local images_json
    images_json=$("${DISCOVER_SCRIPT}" --format=json)

    if [[ "$images_json" == "[]" ]]; then
        echo "No images found to build."
        exit 0
    fi

    local item context name tag

    while IFS= read -r item; do
        context=$(printf '%s' "$item" | jq -r '.context')
        name=$(printf '%s' "$item" | jq -r '.name')
        tag=$(printf '%s' "$item" | jq -r '.tag')

        if [[ "$context" != "null" ]] && [[ "$name" != "null" ]] && [[ "$tag" != "null" ]]; then
            echo -e "${YELLOW}Building ${name}:${tag}...${RESET}"
            if docker build --load -q "${context}" -t "local/${name}:${tag}"; then
                echo -e "  ${GREEN}✓ ${name}:${tag} built successfully${RESET}"
            else
                echo -e "  ${RED}✗ Failed to build ${name}:${tag}${RESET}"
                exit 1
            fi
        fi
    done < <(printf '%s' "$images_json" | jq -c '.[]')

    echo -e "${GREEN}Build complete!${RESET}"
}

main "$@"
