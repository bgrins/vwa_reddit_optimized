#!/bin/bash
set -e

rclone copy reddit_docker_rebuild/postmill_dump.sql.xz r2:the-zoo/reddit/ -v --progress
