#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
compose_file="$repo_root/tests/setup/docker-compose.integration.yml"

docker compose -f "$compose_file" up -d postgres minio

wait_healthy() {
  local service="$1"
  local container_id
  container_id=$(docker compose -f "$compose_file" ps -q "$service")

  if [[ -z "$container_id" ]]; then
    echo "Unable to find container for service: $service" >&2
    exit 1
  fi

  for _ in $(seq 1 60); do
    status=$(docker inspect --format '{{.State.Health.Status}}' "$container_id" 2>/dev/null || true)
    if [[ "$status" == "healthy" ]]; then
      return 0
    fi
    sleep 1
  done

  echo "Service did not become healthy: $service" >&2
  docker compose -f "$compose_file" logs "$service" >&2 || true
  exit 1
}

wait_healthy postgres
wait_healthy minio

docker compose -f "$compose_file" run --rm minio-provision

echo "PostgreSQL and MinIO are ready for integration tests."
