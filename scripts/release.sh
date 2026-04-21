#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/release.sh [--version <version>] [--source <nuget-source>] [--out <dir>] [--api-key <key>] [--run-benchmarks <0|1>] [--run-consumer-e2e <0|1>] [--yes]

Interactive defaults:
  version: prompted
  source: https://api.nuget.org/v3/index.json
  out: /tmp/ids4-pack-<version>
  run benchmarks: 1
  run consumer e2e: 1

Environment passthrough (benchmark profile/settings):
  BENCH_PROFILE, BENCH_AUTO_HOST, BENCH_BASE_URL, BENCH_TOKEN_PATH,
  BENCH_CLIENT_ID, BENCH_CLIENT_SECRET, BENCH_SCOPE, BENCH_DURATION, BENCH_REQUIRE_429
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEFAULT_SOURCE="https://api.nuget.org/v3/index.json"
VERIFY_SCRIPT="$ROOT_DIR/scripts/verify.sh"
PACK_SCRIPT="$ROOT_DIR/scripts/pack.sh"
PUBLISH_SCRIPT="$ROOT_DIR/scripts/publish.sh"
E2E_CONSUMER_SCRIPT="$ROOT_DIR/scripts/e2e-consumer.sh"

VERSION="${VERSION:-}"
SOURCE="${SOURCE:-}"
OUT="${OUT:-}"
NUGET_API_KEY="${NUGET_API_KEY:-}"
RUN_BENCHMARKS="${RUN_BENCHMARKS:-}"
RUN_CONSUMER_E2E="${RUN_CONSUMER_E2E:-}"
ASSUME_YES=0

prompt_required() {
  local prompt_text="$1"
  local var_name="$2"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -p "$prompt_text" value
  done
  printf -v "$var_name" "%s" "$value"
}

prompt_secret_masked() {
  local prompt_text="$1"
  local var_name="$2"
  local value=""
  local char=""

  printf "%s" "$prompt_text"
  while IFS= read -r -s -n 1 char; do
    if [[ -z "$char" || "$char" == $'\n' || "$char" == $'\r' ]]; then
      break
    fi

    if [[ "$char" == $'\177' || "$char" == $'\b' ]]; then
      if [[ -n "$value" ]]; then
        value="${value%?}"
        printf '\b \b'
      fi
      continue
    fi

    value+="$char"
    printf '*'
  done
  echo

  printf -v "$var_name" "%s" "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --api-key)
      NUGET_API_KEY="${2:-}"
      shift 2
      ;;
    --run-benchmarks)
      RUN_BENCHMARKS="${2:-}"
      shift 2
      ;;
    --run-consumer-e2e)
      RUN_CONSUMER_E2E="${2:-}"
      shift 2
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  prompt_required "Release version (example: 5.0.0): " VERSION
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid VERSION format: $VERSION" >&2
  echo "Expected semantic version format like 5.0.0 or 5.0.0-rc.1" >&2
  exit 1
fi

if [[ -z "$SOURCE" ]]; then
  read -r -p "NuGet source [$DEFAULT_SOURCE]: " SOURCE
fi
SOURCE="${SOURCE:-$DEFAULT_SOURCE}"

if [[ -z "$OUT" ]]; then
  read -r -p "Output folder [/tmp/ids4-pack-$VERSION]: " OUT
fi
OUT="${OUT:-/tmp/ids4-pack-$VERSION}"

if [[ -z "$RUN_BENCHMARKS" ]]; then
  read -r -p "Run benchmark suite before packing/publishing? [Y/n]: " RUN_BENCHMARKS
fi
case "${RUN_BENCHMARKS:-Y}" in
  n|N|no|NO|0)
    RUN_BENCHMARKS=0
    ;;
  *)
    RUN_BENCHMARKS=1
    ;;
esac

if [[ "$RUN_BENCHMARKS" == "1" ]]; then
  BENCH_PROFILE="${BENCH_PROFILE:-}"
  BENCH_AUTO_HOST="${BENCH_AUTO_HOST:-}"
  BENCH_BASE_URL="${BENCH_BASE_URL:-}"
  BENCH_TOKEN_PATH="${BENCH_TOKEN_PATH:-}"
  BENCH_CLIENT_ID="${BENCH_CLIENT_ID:-}"
  BENCH_CLIENT_SECRET="${BENCH_CLIENT_SECRET:-}"
  BENCH_SCOPE="${BENCH_SCOPE:-}"
  BENCH_DURATION="${BENCH_DURATION:-}"
  BENCH_REQUIRE_429="${BENCH_REQUIRE_429:-}"

  if [[ -z "$BENCH_PROFILE" ]]; then
    read -r -p "Benchmark profile [local/ci] (default: local): " BENCH_PROFILE
  fi
  BENCH_PROFILE="${BENCH_PROFILE:-local}"
  case "$BENCH_PROFILE" in
    local|ci) ;;
    *)
      echo "Invalid BENCH_PROFILE: $BENCH_PROFILE (expected: local or ci)" >&2
      exit 1
      ;;
  esac

  if [[ -z "$BENCH_AUTO_HOST" ]]; then
    read -r -p "Auto-start local IdentityServer host for benchmark? [Y/n]: " BENCH_AUTO_HOST
  fi
  case "${BENCH_AUTO_HOST:-Y}" in
    n|N|no|NO|0)
      BENCH_AUTO_HOST=0
      ;;
    *)
      BENCH_AUTO_HOST=1
      ;;
  esac

  if [[ "$BENCH_AUTO_HOST" == "1" ]]; then
    BENCH_BASE_URL="${BENCH_BASE_URL:-http://127.0.0.1:5000}"
    BENCH_TOKEN_PATH="${BENCH_TOKEN_PATH:-/connect/token}"
    BENCH_CLIENT_ID="${BENCH_CLIENT_ID:-client}"
    BENCH_CLIENT_SECRET="${BENCH_CLIENT_SECRET:-secret}"
    BENCH_SCOPE="${BENCH_SCOPE:-resource1.scope1}"
  else
    prompt_required "Benchmark BASE_URL (example: https://localhost:5001): " BENCH_BASE_URL
    read -r -p "Benchmark TOKEN_PATH [/connect/token]: " BENCH_TOKEN_PATH
    BENCH_TOKEN_PATH="${BENCH_TOKEN_PATH:-/connect/token}"
    prompt_required "Benchmark CLIENT_ID: " BENCH_CLIENT_ID
    prompt_secret_masked "Benchmark CLIENT_SECRET: " BENCH_CLIENT_SECRET
    read -r -p "Benchmark scope [api1]: " BENCH_SCOPE
    BENCH_SCOPE="${BENCH_SCOPE:-api1}"
  fi

  read -r -p "Benchmark duration [30s]: " BENCH_DURATION
  BENCH_DURATION="${BENCH_DURATION:-30s}"
  read -r -p "Require observing HTTP 429 in stress test? [y/N]: " BENCH_REQUIRE_429
  case "${BENCH_REQUIRE_429:-N}" in
    y|Y|yes|YES|1)
      BENCH_REQUIRE_429=1
      ;;
    *)
      BENCH_REQUIRE_429=0
      ;;
  esac
fi

if [[ -z "$RUN_CONSUMER_E2E" ]]; then
  read -r -p "Run consumer E2E package gate before publish? [Y/n]: " RUN_CONSUMER_E2E
fi
case "${RUN_CONSUMER_E2E:-Y}" in
  n|N|no|NO|0)
    RUN_CONSUMER_E2E=0
    ;;
  *)
    RUN_CONSUMER_E2E=1
    ;;
esac

echo
echo "Release plan:"
echo "  Version: $VERSION"
echo "  Source : $SOURCE"
echo "  Output : $OUT"
if [[ "$RUN_BENCHMARKS" == "1" ]]; then
  if [[ "${BENCH_AUTO_HOST:-0}" == "1" ]]; then
    echo "  Bench  : enabled (profile=$BENCH_PROFILE, auto-host, BASE_URL=$BENCH_BASE_URL)"
  else
    echo "  Bench  : enabled (profile=$BENCH_PROFILE, external host, BASE_URL=$BENCH_BASE_URL)"
  fi
else
  echo "  Bench  : skipped"
fi
if [[ "$RUN_CONSUMER_E2E" == "1" ]]; then
  echo "  E2E    : enabled (consumer runtime smoke)"
else
  echo "  E2E    : skipped"
fi
echo "  Pack   : 5 packages"

if [[ "$ASSUME_YES" != "1" ]]; then
  echo
  read -r -p "Proceed with verification, pack, E2E, and publish? [y/N]: " CONFIRM
  case "${CONFIRM:-}" in
    y|Y|yes|YES) ;;
    *)
      echo "Cancelled."
      exit 1
      ;;
  esac
fi

if [[ -z "$NUGET_API_KEY" ]]; then
  prompt_secret_masked "NuGet API key: " NUGET_API_KEY
fi

if [[ -z "$NUGET_API_KEY" ]]; then
  echo "NUGET_API_KEY is required." >&2
  exit 1
fi

if [[ ! -f "$VERIFY_SCRIPT" ]]; then
  echo "Verification script not found: $VERIFY_SCRIPT" >&2
  exit 1
fi
if [[ ! -f "$PACK_SCRIPT" ]]; then
  echo "Pack script not found: $PACK_SCRIPT" >&2
  exit 1
fi
if [[ ! -f "$PUBLISH_SCRIPT" ]]; then
  echo "Publish script not found: $PUBLISH_SCRIPT" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"

echo
echo "==> Running verification"
env \
  RUN_RESTORE=1 \
  RUN_BENCHMARKS="$RUN_BENCHMARKS" \
  BENCH_PROFILE="${BENCH_PROFILE:-}" \
  BENCH_AUTO_HOST="${BENCH_AUTO_HOST:-}" \
  BENCH_BASE_URL="${BENCH_BASE_URL:-}" \
  BENCH_TOKEN_PATH="${BENCH_TOKEN_PATH:-}" \
  BENCH_CLIENT_ID="${BENCH_CLIENT_ID:-}" \
  BENCH_CLIENT_SECRET="${BENCH_CLIENT_SECRET:-}" \
  BENCH_SCOPE="${BENCH_SCOPE:-}" \
  BENCH_DURATION="${BENCH_DURATION:-}" \
  BENCH_REQUIRE_429="${BENCH_REQUIRE_429:-}" \
  bash "$VERIFY_SCRIPT"

echo
echo "==> Packing"
bash "$PACK_SCRIPT" --version "$VERSION" --out "$OUT"

if [[ "$RUN_CONSUMER_E2E" == "1" ]]; then
  if [[ ! -f "$E2E_CONSUMER_SCRIPT" ]]; then
    echo "E2E consumer script not found: $E2E_CONSUMER_SCRIPT" >&2
    exit 1
  fi

  echo
  echo "==> Running consumer E2E gate"
  bash "$E2E_CONSUMER_SCRIPT" --version "$VERSION" --source "$OUT"
fi

echo
echo "==> Publishing"
env NUGET_API_KEY="$NUGET_API_KEY" bash "$PUBLISH_SCRIPT" --version "$VERSION" --out "$OUT" --source "$SOURCE"
