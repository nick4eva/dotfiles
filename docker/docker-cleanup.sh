#!/usr/bin/env bash
# Daily Docker cleanup for this workstation.
# Intentionally does NOT prune containers (kept debug containers)
# and does NOT use `image prune -a` (some images are slow to re-pull).
set -uo pipefail

echo "=== docker-cleanup start $(date '+%F %T') ==="
docker system df

echo "--- dangling images ---"
docker image prune -f

echo "--- unused anonymous volumes ---"
docker volume prune -f

echo "--- build cache (keep 10GB most recently used) ---"
docker builder prune -f --reserved-space 10GB

echo "--- unused networks older than 7 days ---"
docker network prune -f --filter "until=168h"

echo "--- after ---"
docker system df
echo "=== docker-cleanup end $(date '+%F %T') ==="
