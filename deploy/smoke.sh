#!/usr/bin/env bash
set -Eeuo pipefail
: "${SITE_URL:?Set SITE_URL}"
: "${ADMIN_USER:?Set ADMIN_USER}"
: "${ADMIN_PASSWORD:?Set ADMIN_PASSWORD}"
base="${SITE_URL%/}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The public website and health endpoint are available without credentials.
curl --fail --silent --show-error --max-time 30 -D "$tmp/public.headers" "$base/" > "$tmp/public.html"
grep -q 'ng-server-context="ssr"' "$tmp/public.html"
! grep -qi 'X-Robots-Tag:.*noindex' "$tmp/public.headers"
curl --fail --silent --show-error --max-time 30 "$base/api/health" > "$tmp/health.txt"
grep -q Healthy "$tmp/health.txt"
curl --fail --silent --show-error --max-time 30 "$base/robots.txt" > "$tmp/robots.txt"
! grep -qx 'Disallow: /' "$tmp/robots.txt"
# Protect the admin application and the reserved admin API namespace.
for path in /admin/ /api/admin/; do
  status=$(curl --silent --show-error --max-time 30 -o /dev/null -w '%{http_code}' "$base$path")
  [[ "$status" == 401 ]] || { echo "Expected anonymous 401 at $path, got $status" >&2; exit 1; }
done
fetch_admin() {
  curl --fail --silent --show-error --max-time 30 --user "$ADMIN_USER:$ADMIN_PASSWORD" "$base$1"
}
fetch_admin /admin/ > "$tmp/admin.html"
grep -q '<base href="/admin/"' "$tmp/admin.html"
fetch_admin /admin/deploy-smoke-route > "$tmp/admin-route.html"
cmp "$tmp/admin.html" "$tmp/admin-route.html"
asset=$(sed -n 's/.*src="\(main-[^"]*\.js\)".*/\1/p' "$tmp/admin.html" | head -n 1)
[[ -n "$asset" ]]
fetch_admin "/admin/$asset" > "$tmp/admin.js"
[[ -s "$tmp/admin.js" ]]
! grep -qi '<!doctype html' "$tmp/admin.js"
echo 'Production smoke checks passed.'
