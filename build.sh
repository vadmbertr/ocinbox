
#!/usr/bin/env bash
set -euo pipefail

BOX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

OCI_IMAGE="${ocinbox_IMAGE:-ghcr.io/vadmbertr/ocinbox:latest}"

LOCAL_IMAGE="ocinbox:local"
SIF="$BOX/opencode.sif"

case "$(uname -s)" in
    Darwin)
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

    Linux)
        # Convert OCI image to Apptainer SIF
        apptainer pull --force \
            "$SIF" \
            "docker://$OCI_IMAGE"
        ;;

    *)
        echo "Docker or Apptainer CLI required" >&2
        exit 1
        ;;
esac
