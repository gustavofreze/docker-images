#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly IMAGES_DIR="images"
readonly VALID_FORMATS=("json" "readable")
FORMAT="json"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--format=json|readable] [--help]

Options:
    --format=json|readable  Output format (default: json)
    --help                  Show this help message

Examples:
    $SCRIPT_NAME --format=json
    $SCRIPT_NAME --format=readable
EOF
}

validate_format() {
    local format="$1"
    for valid in "${VALID_FORMATS[@]}"; do
        if [[ "$format" == "$valid" ]]; then
            return 0
        fi
    done
    echo "Error: Invalid format '$format'. Use 'json' or 'readable'." >&2
    usage
    exit 1
}

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --format=*)
                local format="${arg#*=}"
                validate_format "$format"
                FORMAT="$format"
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown argument '$arg'" >&2
                usage
                exit 1
                ;;
        esac
    done
    readonly FORMAT
}

install_jq() {
    echo "jq is not installed. Installing..." >&2

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &>/dev/null; then
            sudo yum install -y jq
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y jq
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm jq
        elif command -v apk &>/dev/null; then
            sudo apk add --no-cache jq
        else
            echo "Error: Unable to install jq. Please install it manually." >&2
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
            brew install jq
        else
            echo "Error: Homebrew is not installed. Please install jq manually." >&2
            exit 1
        fi
    else
        echo "Error: Unsupported OS. Please install jq manually." >&2
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: Failed to install jq." >&2
        exit 1
    fi

    echo "jq installed successfully!" >&2
}

check_dependencies() {
    if ! command -v jq &>/dev/null; then
        install_jq
    fi
}

discover_images() {
    local images=()
    local dockerfile context relative_path name version variant tag

    while IFS= read -r dockerfile; do
        context="${dockerfile%/Dockerfile}"
        relative_path="${context#"$IMAGES_DIR"/}"

        IFS='/' read -r name version variant <<< "$relative_path"

        if [[ -n "${variant:-}" ]]; then
            tag="${version}-${variant}"
        else
            tag="${version}"
        fi

        images+=("{\"context\":\"$context\",\"name\":\"$name\",\"tag\":\"$tag\"}")
    done < <(find "$IMAGES_DIR" -name Dockerfile -type f 2>/dev/null)

    if [[ ${#images[@]} -eq 0 ]]; then
        echo "[]"
        return
    fi

    local json_output
    json_output="[$(IFS=,; echo "${images[*]}")]"

    echo "$json_output" | jq -c '.'
}

format_readable() {
    local json_input
    json_input=$(cat)

    echo "Discovered Docker images:"
    echo ""

    echo "$json_input" | jq -r '.[] |
        "  \(.context)\n" +
        "     Name: \(.name)\n" +
        "     Tag:   \(.tag)\n"'
}

main() {
    parse_args "$@"
    check_dependencies

    if [[ ! -d "$IMAGES_DIR" ]]; then
        echo "Error: Directory '$IMAGES_DIR' not found" >&2
        exit 1
    fi

    case "$FORMAT" in
        json)
            discover_images
            ;;
        readable)
            discover_images | format_readable
            ;;
    esac
}

main "$@"
