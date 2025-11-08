#!/bin/bash
set -e

# Parse arguments
CUSTOM_TAG=""
SLIM=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tag)
      CUSTOM_TAG="$2"
      shift 2
      ;;
    --slim)
      SLIM=true
      shift
      ;;
    *)
      # If no --tag flag, treat as tag value
      if [[ -z "$CUSTOM_TAG" && ! "$1" == --* ]]; then
        CUSTOM_TAG="$1"
      fi
      shift
      ;;
  esac
done

if [ "$SLIM" = true ]; then
    echo "Building slim base image (local only)..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t bgrins/vwa-reddit-optimized-base-slim:latest \
      --load \
      reddit_base_image_slim/

    echo "Building and pushing slim standalone variant..."
    STANDALONE_TAGS="-t ghcr.io/bgrins/vwa-reddit-optimized-standalone-slim:latest"
    if [[ -n "$CUSTOM_TAG" ]]; then
      STANDALONE_TAGS="$STANDALONE_TAGS -t ghcr.io/bgrins/vwa-reddit-optimized-standalone-slim:$CUSTOM_TAG"
    fi
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      $STANDALONE_TAGS \
      --push \
      reddit_docker_rebuild_slim/

    echo "✓ Built slim base locally and pushed standalone-slim to GHCR"
    echo ""
    echo "Images pushed:"
    if [[ -n "$CUSTOM_TAG" ]]; then
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone-slim:latest"
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone-slim:$CUSTOM_TAG"
    else
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone-slim:latest"
    fi
else
    echo "Building base image (local only)..."
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      -t bgrins/vwa-reddit-optimized-base:latest \
      --load \
      reddit_base_image/

    echo "Building and pushing bundled variant (with PostgreSQL)..."
    BUNDLED_TAGS="-t ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest"
    if [[ -n "$CUSTOM_TAG" ]]; then
      BUNDLED_TAGS="$BUNDLED_TAGS -t ghcr.io/bgrins/vwa-reddit-optimized-bundled:$CUSTOM_TAG"
    fi
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --target with-postgres \
      $BUNDLED_TAGS \
      --push \
      reddit_docker_rebuild/

    echo "Building and pushing standalone variant (external database)..."
    STANDALONE_TAGS="-t ghcr.io/bgrins/vwa-reddit-optimized-standalone:latest"
    if [[ -n "$CUSTOM_TAG" ]]; then
      STANDALONE_TAGS="$STANDALONE_TAGS -t ghcr.io/bgrins/vwa-reddit-optimized-standalone:$CUSTOM_TAG"
    fi
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --target without-postgres \
      $STANDALONE_TAGS \
      --push \
      reddit_docker_rebuild/

    echo "✓ Built base locally and pushed both variants to GHCR"
    echo ""
    echo "Images pushed:"
    if [[ -n "$CUSTOM_TAG" ]]; then
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest (with PostgreSQL)"
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-bundled:$CUSTOM_TAG (with PostgreSQL)"
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone:latest (external DB)"
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone:$CUSTOM_TAG (external DB)"
    else
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest (with PostgreSQL)"
      echo "  - ghcr.io/bgrins/vwa-reddit-optimized-standalone:latest (external DB)"
    fi
fi