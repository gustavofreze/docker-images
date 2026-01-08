#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly RESET='\033[0m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly REPO_OWNER="gustavofreze"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCOVER_SCRIPT="${SCRIPTS_DIR}/discover-images.sh"

echo "Building Docker images..."

chmod +x "${DISCOVER_SCRIPT}"

images_json=$("${DISCOVER_SCRIPT}" --format=json)

if [[ $(echo "$images_json" | jq '. | length') -eq 0 ]]; then
    echo "No images found to build."
    exit 0
fi

count=$(echo "$images_json" | jq '. | length')
for ((i=0; i<count; i++)); do
    context=$(echo "$images_json" | jq -r ".[$i].context")
    name=$(echo "$images_json" | jq -r ".[$i].name")
    tag=$(echo "$images_json" | jq -r ".[$i].tag")

    if [[ -n "$context" ]] && [[ -n "$name" ]] && [[ -n "$tag" ]]; then
        full_image_name="${REPO_OWNER}/${name}:${tag}"

        echo -e "${YELLOW}Building ${full_image_name}...${RESET}"

        if docker build --load -q "${context}" -t "${full_image_name}"; then
            echo -e "  ${GREEN}✓ ${full_image_name} built successfully${RESET}"
        else
            echo -e "  ${RED}✗ Failed to build ${full_image_name}${RESET}"
            exit 1
        fi
    fi
done

echo -e "${GREEN}Build complete!${RESET}"
