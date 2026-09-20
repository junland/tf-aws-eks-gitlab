#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
compose_file="$repo_root/tests/setup/docker-compose.integration.yml"

docker compose -f "$compose_file" down -v --remove-orphans
