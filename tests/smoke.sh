#!/usr/bin/env bash
# Smoke test for the runbrowser image. Builds, starts, hits /json/version,
# tears down. No external dependencies beyond docker.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$SCRIPT_DIR"

cleanup() {
    docker compose down >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> building"
docker compose build

echo "==> starting"
docker compose up -d

echo "==> waiting for healthy (up to 30s)"
for i in {1..30}; do
    status="$(docker inspect -f '{{.State.Health.Status}}' runbrowser 2>/dev/null || echo starting)"
    if [ "$status" = "healthy" ]; then
        echo "    healthy after ${i}s"
        break
    fi
    sleep 1
done
if [ "$status" != "healthy" ]; then
    echo "FAIL: container never became healthy"
    docker compose logs runbrowser
    exit 1
fi

echo "==> probing /json/version"
response="$(curl -fsS http://localhost:9222/json/version)"
echo "$response" | head -c 200; echo
if ! echo "$response" | grep -q webSocketDebuggerUrl; then
    echo "FAIL: /json/version did not return webSocketDebuggerUrl"
    exit 1
fi

echo "==> ok"
