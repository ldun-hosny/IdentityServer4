#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$ROOT_DIR/benchmark"
OUT_DIR="${BENCH_OUT_DIR:-/tmp/ids4-benchmark}"
TARGETS_FILE="$BENCH_DIR/targets.json"
HOST_PROJECT="$ROOT_DIR/src/IdentityServer4/host/Host.csproj"
HOST_PROJECT_DIR="$(cd "$(dirname "$HOST_PROJECT")" && pwd)"
HOST_BASE_URL="${HOST_BASE_URL:-http://127.0.0.1:5000}"
HOST_LOG="$OUT_DIR/identityserver-host.log"

BASE_URL="${BASE_URL:-}"
TOKEN_PATH="${TOKEN_PATH:-/connect/token}"
CLIENT_ID="${CLIENT_ID:-client}"
CLIENT_SECRET="${CLIENT_SECRET:-secret}"
SCOPE="${SCOPE:-resource1.scope1}"
BENCH_PROFILE="${BENCH_PROFILE:-}"

AUTO_HOST="${AUTO_HOST:-}"
if [[ -z "$AUTO_HOST" ]]; then
  if [[ -n "$BASE_URL" ]]; then
    AUTO_HOST=0
  else
    AUTO_HOST=1
  fi
fi

if [[ -z "$BASE_URL" ]]; then
  BASE_URL="$HOST_BASE_URL"
fi

export BASE_URL TOKEN_PATH CLIENT_ID CLIENT_SECRET SCOPE

command -v k6 >/dev/null 2>&1 || { echo "k6 is required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }

if [[ -z "$BENCH_PROFILE" ]]; then
  if [[ "${CI:-}" == "true" || "${CI:-}" == "1" || -n "${GITHUB_ACTIONS:-}" ]]; then
    BENCH_PROFILE="ci"
  else
    BENCH_PROFILE="local"
  fi
fi

profile_exists="$(jq -r --arg profile "$BENCH_PROFILE" '.profiles[$profile] != null' "$TARGETS_FILE")"
if [[ "$profile_exists" != "true" ]]; then
  echo "Unknown BENCH_PROFILE='$BENCH_PROFILE' in $TARGETS_FILE" >&2
  echo "Available profiles: $(jq -r '.profiles | keys | join(", ")' "$TARGETS_FILE")" >&2
  exit 1
fi

read_profile_target() {
  local profile_path="$1"
  local fallback_path="$2"
  jq -r --arg profile "$BENCH_PROFILE" "$profile_path // $fallback_path // empty" "$TARGETS_FILE"
}

profile_min_tps="$(read_profile_target '.profiles[$profile].throughput.min_tokens_per_second' '.throughput.min_tokens_per_second')"
profile_max_p95_ms="$(read_profile_target '.profiles[$profile].throughput.max_p95_latency_ms' '.throughput.max_p95_latency_ms')"
profile_min_429_required="$(read_profile_target '.profiles[$profile].rate_limit.min_429_count_when_required' '.rate_limit.min_429_count_when_required')"

MIN_TPS="${MIN_TPS:-$profile_min_tps}"
MAX_P95_LATENCY_MS="${MAX_P95_LATENCY_MS:-$profile_max_p95_ms}"
MIN_429_REQUIRED="${MIN_429_REQUIRED:-$profile_min_429_required}"
HTTP_REQ_DURATION_P95_MS="${HTTP_REQ_DURATION_P95_MS:-$MAX_P95_LATENCY_MS}"

if [[ -z "$MIN_TPS" || ! "$MIN_TPS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "MIN_TPS must be numeric (current value: '$MIN_TPS')." >&2
  exit 1
fi

if [[ -z "$HTTP_REQ_DURATION_P95_MS" || ! "$HTTP_REQ_DURATION_P95_MS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "HTTP_REQ_DURATION_P95_MS must be numeric (current value: '$HTTP_REQ_DURATION_P95_MS')." >&2
  exit 1
fi

if [[ -z "$MIN_429_REQUIRED" || ! "$MIN_429_REQUIRED" =~ ^[0-9]+$ ]]; then
  echo "MIN_429_REQUIRED must be an integer (current value: '$MIN_429_REQUIRED')." >&2
  exit 1
fi

export HTTP_REQ_DURATION_P95_MS

mkdir -p "$OUT_DIR"

THROUGHPUT_SUMMARY="$OUT_DIR/token-throughput-summary.json"
RATE_LIMIT_SUMMARY="$OUT_DIR/rate-limit-summary.json"

HOST_PID=""

cleanup() {
  if [[ -n "$HOST_PID" ]] && kill -0 "$HOST_PID" >/dev/null 2>&1; then
    kill "$HOST_PID" >/dev/null 2>&1 || true
    wait "$HOST_PID" >/dev/null 2>&1 || true
  fi
}

wait_for_host() {
  local url="$1"
  local max_attempts=90
  local i=0

  until [[ "$i" -ge "$max_attempts" ]]; do
    if curl -fsS "$url/.well-known/openid-configuration" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done

  return 1
}

trap cleanup EXIT

if [[ "$AUTO_HOST" == "1" ]]; then
  if [[ ! -f "$HOST_PROJECT" ]]; then
    echo "IdentityServer host project not found: $HOST_PROJECT"
    exit 1
  fi

  echo "==> Starting local IdentityServer host for benchmarks"
  echo "Base URL: $BASE_URL"
  (
    cd "$HOST_PROJECT_DIR"
    ASPNETCORE_URLS="$BASE_URL" dotnet run --project "$HOST_PROJECT" -c Release --no-launch-profile
  ) >"$HOST_LOG" 2>&1 &
  HOST_PID=$!

  if ! wait_for_host "$BASE_URL"; then
    echo "Host did not become ready at $BASE_URL"
    echo "Host log (tail):"
    tail -n 80 "$HOST_LOG" || true
    exit 1
  fi
fi

echo "==> Benchmark profile: $BENCH_PROFILE"
echo "    min tokens/sec: $MIN_TPS"
echo "    max p95 latency (ms): $HTTP_REQ_DURATION_P95_MS"
echo "    min 429 (when REQUIRE_429=1): $MIN_429_REQUIRED"

echo "==> Running token throughput test"
k6 run "$BENCH_DIR/k6/token-throughput.js" --summary-export "$THROUGHPUT_SUMMARY"

duration_raw="${DURATION:-30s}"
duration_seconds="$(echo "$duration_raw" | sed 's/s$//')"
if [[ -z "$duration_seconds" || ! "$duration_seconds" =~ ^[0-9]+$ ]]; then
  echo "DURATION must be in whole seconds format like 30s"
  exit 1
fi

tokens_issued="$(jq -r '.metrics.tokens_issued.values.count // .metrics.tokens_issued.count // 0' "$THROUGHPUT_SUMMARY")"
tokens_per_second="$(awk -v c="$tokens_issued" -v d="$duration_seconds" 'BEGIN { if (d == 0) print 0; else printf "%.2f", c/d }')"

echo "Throughput result: $tokens_per_second tokens/sec (target >= $MIN_TPS)"
if awk -v tps="$tokens_per_second" -v min="$MIN_TPS" 'BEGIN { exit !(tps >= min) }'; then
  echo "Throughput target met"
else
  echo "Throughput target NOT met"
  exit 1
fi

echo "==> Running rate-limit stress test"
k6 run "$BENCH_DIR/k6/rate-limit-stress.js" --summary-export "$RATE_LIMIT_SUMMARY"

status_429_count="$(jq -r '.metrics.status_429.values.count // .metrics.status_429.count // 0' "$RATE_LIMIT_SUMMARY")"
echo "Rate-limit result: 429 count=$status_429_count"

if [[ "${REQUIRE_429:-0}" == "1" ]]; then
  if (( status_429_count < MIN_429_REQUIRED )); then
    echo "Expected at least $MIN_429_REQUIRED HTTP 429 responses but got $status_429_count"
    exit 1
  fi
  echo "Rate-limit requirement met"
fi

echo "Benchmark suite passed"
echo "Summaries:"
echo "  $THROUGHPUT_SUMMARY"
echo "  $RATE_LIMIT_SUMMARY"
