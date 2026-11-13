#!/usr/bin/env bash
set -euo pipefail

BOX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

OCI_IMAGE="${ocinbox_IMAGE:-ghcr.io/vadmbertr/ocinbox:latest}"

LOCAL_IMAGE="ocinbox:local"
SIF="$BOX/opencode.sif"

# Detect container runtime
if command -v docker >/dev/null 2>&1; then
    RUNTIME=docker
elif command -v apptainer >/dev/null 2>&1; then
    RUNTIME=apptainer
else
    echo "Neither a working Docker runtime nor Apptainer is available" >&2
    exit 1
fi

case "$RUNTIME" in
    docker)
        ACTION="${1:-build}"
        case "$ACTION" in
            build)
                docker build -t "$LOCAL_IMAGE" "$BOX"
                ;;

            publish)
                # Publish both architectures
                docker buildx build \
                    --platform linux/amd64,linux/arm64 \
                    -t "$OCI_IMAGE" \
                    --push \
                    "$BOX"
                ;;

            sync)
                # Use the image published to GHCR
                docker pull "$OCI_IMAGE"
                docker tag "$OCI_IMAGE" "$LOCAL_IMAGE"
                ;;

            *)
                echo "Usage: $0 [build|publish|sync]" >&2
                exit 1
                ;;
        esac
        ;;

    apptainer)
        # Convert OCI image to Apptainer SIF
        apptainer pull --force \
            "$SIF" \
            "docker://$OCI_IMAGE"
        ;;
esac
