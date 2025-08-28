#!/bin/bash
set -e

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target with-postgres \
  -t bgrins/vwa-reddit-optimized-bundled:latest \
  reddit_docker_rebuild/

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target without-postgres \
  -t bgrins/vwa-reddit-optimized-standalone:latest \
  reddit_docker_rebuild/
