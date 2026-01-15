#!/bin/bash
set -e

CONTAINER_NAME="hls-transcoder"
IMAGE_NAME="hls-transcoder"
WORK_DIR="$(git rev-parse --show-toplevel)"

FORCE_REBUILD=false
CPU_OPTS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-rebuild)
            FORCE_REBUILD=true
            shift
            ;;
        --cpus)
            CPU_OPTS="--cpus=$2"
            shift 2
            ;;
        --cpuset-cpus)
            CPU_OPTS="--cpuset-cpus=$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--force-rebuild] [--cpus N] [--cpuset-cpus 0-3]" >&2
            exit 1
            ;;
    esac
done

if [[ "$FORCE_REBUILD" == true ]] || ! podman image exists "$IMAGE_NAME"; then
    podman build -t "$IMAGE_NAME" -f "$WORK_DIR/Containerfile" "$WORK_DIR"
fi

prompt_directory() {
    local prompt_msg="$1"
    local dir_path=""

    read -e -p "$prompt_msg" dir_path

    if [[ -z "$dir_path" ]]; then
        echo "Error: No directory provided" >&2
        return 1
    fi

    dir_path="${dir_path/#\~/$HOME}"

    if [[ ! -d "$dir_path" ]]; then
        echo "Error: Directory does not exist: $dir_path" >&2
        return 1
    fi

    dir_path="$(cd "$dir_path" && pwd)"

    echo "$dir_path"
}

if [[ "$FORCE_REBUILD" == true ]]; then
    podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
elif podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    exec podman attach "$CONTAINER_NAME"
elif podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    podman start "$CONTAINER_NAME"
    exec podman attach "$CONTAINER_NAME"
fi

STAGED_DIR=$(prompt_directory "Enter host path to mount as /staged directory in the container context: ")
if [[ $? -ne 0 ]]; then
    exit 1
fi

PROCESSED_DIR=$(prompt_directory "Enter host path to mount as /processed directory in the container context: ")
if [[ $? -ne 0 ]]; then
    exit 1
fi

podman run -it \
    --name "$CONTAINER_NAME" \
    --userns=keep-id \
    $CPU_OPTS \
    -v "$WORK_DIR:/workspace" \
    -v "$STAGED_DIR:/staged" \
    -v "$PROCESSED_DIR:/processed" \
    -w /workspace \
    "$IMAGE_NAME"
