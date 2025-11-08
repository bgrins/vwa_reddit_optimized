#!/bin/bash
set -e

# Parse arguments
SLIM=false
if [[ "$1" == "--slim" ]]; then
    SLIM=true
fi

if [ "$SLIM" = true ]; then
    echo "Building slim base image..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t bgrins/vwa-reddit-optimized-base-slim:latest \
      --load \
      reddit_base_image_slim/

    echo "Building slim standalone variant..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t bgrins/vwa-reddit-optimized-standalone-slim:latest \
      --load \
      reddit_docker_rebuild_slim/

    echo "✓ Build complete!"
    echo ""
    echo "Images available:"
    echo "  - bgrins/vwa-reddit-optimized-base-slim:latest"
    echo "  - bgrins/vwa-reddit-optimized-standalone-slim:latest"
else
    # Build the base image first (contains app + images)
    echo "Building base image..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t bgrins/vwa-reddit-optimized-base:latest \
      --load \
      reddit_base_image/

    # Build the variants
    echo "Building bundled variant (with PostgreSQL)..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --target with-postgres \
      -t bgrins/vwa-reddit-optimized-bundled:latest \
      --load \
      reddit_docker_rebuild/

    echo "Building standalone variant (external database)..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --target without-postgres \
      -t bgrins/vwa-reddit-optimized-standalone:latest \
      --load \
      reddit_docker_rebuild/

    echo "✓ Build complete!"
    echo "Images available:"
    echo "  - bgrins/vwa-reddit-optimized-base:latest"
    echo "  - bgrins/vwa-reddit-optimized-bundled:latest"
    echo "  - bgrins/vwa-reddit-optimized-standalone:latest"
fi