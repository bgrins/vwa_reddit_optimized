#!/bin/bash
set -e

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

echo "✓ Built and pushed both variants to Docker Hub"
echo ""
echo "Images available:"
echo "  - bgrins/vwa-reddit-optimized-bundled:latest (with PostgreSQL)"
echo "  - bgrins/vwa-reddit-optimized-standalone:latest (external DB)"