#!/bin/bash
set -e

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target with-postgres \
  -t bgrins/vwa-reddit-optimized-bundled:latest \
  --push \
  reddit_docker_rebuild/

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target without-postgres \
  -t bgrins/vwa-reddit-optimized-standalone:latest \
  --push \
  reddit_docker_rebuild/

echo "✓ Built and pushed both variants to Docker Hub"
echo ""
echo "Images available:"
echo "  - bgrins/vwa-reddit-optimized-bundled:latest (with PostgreSQL)"
echo "  - bgrins/vwa-reddit-optimized-standalone:latest (external DB)"