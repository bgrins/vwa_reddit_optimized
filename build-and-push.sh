#!/bin/bash
set -e

# Parse arguments
SLIM=false
if [[ "$1" == "--slim" ]]; then
    SLIM=true
fi

if [ "$SLIM" = true ]; then
    echo "Building slim base image (local only)..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t bgrins/vwa-reddit-optimized-base-slim:latest \
      --load \
      reddit_base_image_slim/

    echo "Building and pushing slim standalone variant..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t ghcr.io/bgrins/vwa-reddit-optimized-standalone-slim:latest \
      --push \
      reddit_docker_rebuild_slim/

    echo "✓ Built slim base image locally and pushed standalone-slim to GHCR"
    echo ""
    echo "Images available:"
    echo "  - bgrins/vwa-reddit-optimized-base-slim:latest (local only)"
    echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone-slim:latest (~15GB)"
else
    echo "Building base image..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t bgrins/vwa-reddit-optimized-base:latest \
      --load \
      reddit_base_image/

    echo "Building and pushing bundled variant (with PostgreSQL)..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --target with-postgres \
      -t ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest \
      --push \
      reddit_docker_rebuild/

    echo "Building and pushing standalone variant (external database)..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --target without-postgres \
      -t ghcr.io/bgrins/vwa-reddit-optimized-standalone:latest \
      --push \
      reddit_docker_rebuild/

    echo "✓ Built and pushed both variants to GHCR"
    echo ""
    echo "Images available:"
    echo "  - ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest (with PostgreSQL)"
    echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone:latest (external DB)"
fi