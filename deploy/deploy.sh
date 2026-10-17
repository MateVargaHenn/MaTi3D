#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
[[ -f .env ]] || { echo "Missing .env" >&2; exit 1; }
[[ -f deploy/admin.htpasswd ]] || { echo "Missing deploy/admin.htpasswd" >&2; exit 1; }
compose=(docker compose --env-file .env -f deploy/compose.yml)
"${compose[@]}" config --quiet
"${compose[@]}" build --pull
"${compose[@]}" up -d --wait --wait-timeout 180
"${compose[@]}" exec -T gateway nginx -t
"${compose[@]}" exec -T gateway nginx -s reload
"${compose[@]}" ps
