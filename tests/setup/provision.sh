#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
compose_file="$repo_root/tests/setup/docker-compose.integration.yml"

docker compose -f "$compose_file" up -d postgres minio
docker compose -f "$compose_file" run --rm minio-provision

echo "PostgreSQL and MinIO are ready for integration tests."
