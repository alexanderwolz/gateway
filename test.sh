#!/bin/bash
# Copyright (C) 2026 Alexander Wolz <mail@alexanderwolz.de>
#
# Smoke test for the gateway container: builds/starts it via docker compose
# and exercises NGINX, LUA and MaxMind GeoIP2 functionality end to end.
#
# Usage:
#   ./test.sh [--build] [--keep] [--timeout SECONDS]
#
#   --build            rebuild the image before starting the container
#   --keep             do not stop/remove the container after the test run
#   --timeout SECONDS  seconds to wait for the container to become healthy (default: 30)

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"
SERVICE="gateway"
# dedicated project name so the test gets its own network/volumes and never
# touches a real "gateway" deployment's persistent geoip volume/data
PROJECT="gateway-smoketest"

BUILD=0
KEEP=0
TIMEOUT=30

while [ $# -gt 0 ]; do
    case "$1" in
        --build) BUILD=1 ;;
        --keep) KEEP=1 ;;
        --timeout) TIMEOUT="$2"; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

function pass() { PASS=$((PASS + 1)); printf "${GREEN}PASS${NC}  %s\n" "$1"; }
function fail() { FAIL=$((FAIL + 1)); printf "${RED}FAIL${NC}  %s\n" "$1"; }
function info() { printf "${YELLOW}--${NC}    %s\n" "$1"; }

function compose() {
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT" "$@"
}

function cleanup() {
    if [ "$KEEP" -eq 0 ]; then
        info "Stopping container and removing test volumes.."
        # -v is safe here: this project's volumes are ephemeral and scoped to
        # $PROJECT, never the ones a real "gateway" deployment persists data in
        compose down -v >/dev/null 2>&1
    else
        info "Leaving container running (--keep)"
    fi
}
trap cleanup EXIT

# assert that a curl response body matches a pattern (grep -E)
function assert_body() {
    local DESC="$1" PATTERN="$2" HOST="$3" PATH_="$4" EXTRA_CURL_ARGS="${5:-}"
    local BODY
    BODY=$(curl -s -k -H "Host: $HOST" $EXTRA_CURL_ARGS "http://localhost$PATH_")
    if echo "$BODY" | grep -qE "$PATTERN"; then
        pass "$DESC"
    else
        fail "$DESC (got: '$BODY')"
    fi
}

# assert an HTTP status code
function assert_status() {
    local DESC="$1" EXPECTED="$2" HOST="$3" PATH_="$4" SCHEME="${5:-http}"
    local CODE
    CODE=$(curl -s -k -o /dev/null -w '%{http_code}' -H "Host: $HOST" "$SCHEME://localhost$PATH_")
    if [ "$CODE" = "$EXPECTED" ]; then
        pass "$DESC"
    else
        fail "$DESC (expected $EXPECTED, got $CODE)"
    fi
}

echo "=== Building / starting gateway container ==="
if [ "$BUILD" -eq 1 ]; then
    compose build || { echo "docker compose build failed" >&2; exit 1; }
fi
compose up -d || { echo "docker compose up failed" >&2; exit 1; }

echo "=== Waiting up to ${TIMEOUT}s for container to become healthy ==="
ELAPSED=0
STATUS="starting"
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    STATUS=$(docker inspect --format '{{.State.Health.Status}}' "$SERVICE" 2>/dev/null || echo "unknown")
    [ "$STATUS" = "healthy" ] && break
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ "$STATUS" = "healthy" ]; then
    pass "Container reports healthy status"
else
    fail "Container did not become healthy within ${TIMEOUT}s (status: $STATUS)"
fi

echo ""
echo "=== NGINX ==="

# config syntax valid inside the running container
if docker exec "$SERVICE" /opt/openresty/bin/openresty -t >/tmp/nginx-t.$$ 2>&1; then
    pass "nginx config syntax is valid"
else
    fail "nginx config syntax is valid"
    sed 's/^/       /' /tmp/nginx-t.$$
fi
rm -f /tmp/nginx-t.$$

assert_body   "GET /health returns status up"        '"status":"up"'          "localhost"   "/health"
assert_body   "GET /whoami returns hostname"          "You reached:"           "localhost"   "/whoami"
assert_body   "vhost example.com serves root"         "Hello, this is example\.com" "example.com" "/"
assert_status "unknown Host on :80 hits default vhost (444)" "000" "not-configured.invalid" "/"

echo ""
echo "=== LUA ==="

assert_body "GET /lua runs custom LUA module"    "Hello from LUA"     "example.com" "/lua"
assert_body "LUA reads ENV_VARIABLE from environment" "Hello from Env" "example.com" "/lua"

echo ""
echo "=== MaxMind GeoIP2 ==="

if docker exec "$SERVICE" test -s /etc/geoip/GeoLite2-Country.mmdb; then
    pass "GeoLite2-Country.mmdb is present and non-empty"
else
    fail "GeoLite2-Country.mmdb is present and non-empty"
fi

if docker exec "$SERVICE" test -s /etc/geoip/GeoLite2-City.mmdb; then
    pass "GeoLite2-City.mmdb is present and non-empty"
else
    fail "GeoLite2-City.mmdb is present and non-empty"
fi

# make a logged request, then confirm the geoip2 module populated the
# access log fields (proves ngx_http_geoip2_module loaded + resolved vars).
# access.log is symlinked to /dev/stdout of the main container process, so it
# must be read via `docker logs` -- a `docker exec ... tail access.log` would
# read the exec session's own (empty, non-EOF) stdout and hang forever.
curl -s -k -H "Host: localhost" "http://localhost/whoami" >/dev/null
sleep 0.2
LOG_LINE=$(docker logs --tail 50 "$SERVICE" 2>/dev/null | grep '"log_type":"http"' | tail -n 1)
if echo "$LOG_LINE" | grep -q '"country_code":'; then
    pass "access log contains geoip2 country_code field"
else
    fail "access log contains geoip2 country_code field (got: '$LOG_LINE')"
fi

# fake the client IP via X-Forwarded-For (trusted for testing on the
# example.com vhost, see config/example.com.conf) and confirm the sample
# mmdb resolves it to the expected geo data (8.8.8.8 -> US / Mountain View)
GEOIP_RESPONSE=$(curl -s -k -H "Host: example.com" -H "X-Forwarded-For: 8.8.8.8" "http://localhost/geoip")
if echo "$GEOIP_RESPONSE" | grep -q "remote_addr=8.8.8.8"; then
    pass "X-Forwarded-For fakes remote_addr as 8.8.8.8"
else
    fail "X-Forwarded-For fakes remote_addr as 8.8.8.8 (got: '$GEOIP_RESPONSE')"
fi
if echo "$GEOIP_RESPONSE" | grep -q "country_code=US"; then
    pass "geoip2 resolves faked IP 8.8.8.8 to country US"
else
    fail "geoip2 resolves faked IP 8.8.8.8 to country US (got: '$GEOIP_RESPONSE')"
fi

echo ""
echo "=== SSL / fake certificate ==="

CERT_SUBJECT=$(echo | openssl s_client -connect localhost:443 -servername gateway 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
if echo "$CERT_SUBJECT" | grep -q "CN[[:space:]]*=[[:space:]]*gateway"; then
    pass "TLS handshake succeeds with self-signed gateway certificate"
else
    fail "TLS handshake succeeds with self-signed gateway certificate (got: '$CERT_SUBJECT')"
fi

echo ""
echo "=== /files static content ==="
assert_status "GET /files/ serves mounted html volume" "200" "example.com" "/files/"

echo ""
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "=== Recent container logs ==="
    docker logs --tail 50 "$SERVICE"
    exit 1
fi

exit 0
