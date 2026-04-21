#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/verify.sh [--run-restore <0|1>] [--run-benchmarks <0|1>]

Optional:
  --run-restore     Restore all solutions before build/test (default: 1)
  --run-benchmarks  Run benchmark suite (default: 1 locally, 0 in CI)

Environment passthrough:
  BENCH_PROFILE, BENCH_AUTO_HOST, BENCH_BASE_URL, BENCH_TOKEN_PATH,
  BENCH_CLIENT_ID, BENCH_CLIENT_SECRET, BENCH_SCOPE, BENCH_DURATION, BENCH_REQUIRE_429
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# NuGet.config includes a local source (./nuget). Ensure it exists on clean runners.
mkdir -p "$ROOT_DIR/nuget"

NUGET_CONFIG="$ROOT_DIR/NuGet.config"
BENCHMARK_SCRIPT="$ROOT_DIR/benchmark/run.sh"

if [[ -n "${RUN_BENCHMARKS+x}" ]]; then
  RUN_BENCHMARKS="${RUN_BENCHMARKS}"
elif [[ "${CI:-}" == "true" || "${CI:-}" == "1" || -n "${GITHUB_ACTIONS:-}" ]]; then
  RUN_BENCHMARKS=0
else
  RUN_BENCHMARKS=1
fi
RUN_RESTORE="${RUN_RESTORE:-1}"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-2}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-2}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-restore)
      RUN_RESTORE="${2:-}"
      shift 2
      ;;
    --run-benchmarks)
      RUN_BENCHMARKS="${2:-}"
      shift 2
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

RESTORE_SOLUTIONS=(
  "src/Storage/IdentityServer4.Storage.sln"
  "src/IdentityServer4/IdentityServer4.sln"
  "src/AspNetIdentity/IdentityServer4.AspNetIdentity.sln"
  "src/EntityFramework.Storage/IdentityServer4.EntityFramework.Storage.sln"
  "src/EntityFramework/IdentityServer4.EntityFramework.sln"
)

BUILD_SOLUTIONS=(
  "src/Storage/IdentityServer4.Storage.sln"
  "src/IdentityServer4/IdentityServer4.sln"
  "src/AspNetIdentity/IdentityServer4.AspNetIdentity.sln"
  "src/EntityFramework.Storage/IdentityServer4.EntityFramework.Storage.sln"
  "src/EntityFramework/IdentityServer4.EntityFramework.sln"
)

TEST_PROJECTS=(
  "src/IdentityServer4/test/IdentityServer.UnitTests/IdentityServer.UnitTests.csproj"
  "src/IdentityServer4/test/IdentityServer.IntegrationTests/IdentityServer.IntegrationTests.csproj"
  "src/EntityFramework.Storage/test/UnitTests/IdentityServer4.EntityFramework.UnitTests.csproj"
  "src/EntityFramework.Storage/test/IntegrationTests/IdentityServer4.EntityFramework.IntegrationTests.csproj"
)

VULNERABILITY_PROJECTS=(
  "src/IdentityServer4/src/IdentityServer4.csproj"
  "src/AspNetIdentity/src/IdentityServer4.AspNetIdentity.csproj"
  "src/EntityFramework.Storage/src/IdentityServer4.EntityFramework.Storage.csproj"
)

run_with_retry() {
  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi

    if (( attempt >= RETRY_ATTEMPTS )); then
      return 1
    fi

    echo "Command failed (attempt $attempt/$RETRY_ATTEMPTS). Retrying in ${RETRY_DELAY_SECONDS}s: $*"
    attempt=$((attempt + 1))
    sleep "$RETRY_DELAY_SECONDS"
  done
}

if [[ "$RUN_RESTORE" == "1" ]]; then
  echo "==> Restoring solutions"
  for solution in "${RESTORE_SOLUTIONS[@]}"; do
    echo "dotnet restore $solution --nologo -v normal"
    run_with_retry dotnet restore "$solution" --nologo -v normal
  done
else
  echo "==> Restore step skipped (RUN_RESTORE=0)."
fi

echo
echo "==> Building solutions"
for solution in "${BUILD_SOLUTIONS[@]}"; do
  if [[ "$RUN_RESTORE" == "1" ]]; then
    echo "dotnet build $solution -c Release --nologo --no-restore"
    run_with_retry dotnet build "$solution" -c Release --nologo --no-restore
  else
    echo "dotnet build $solution -c Release --nologo"
    run_with_retry dotnet build "$solution" -c Release --nologo
  fi
done

echo
echo "==> Running tests"
for test_project in "${TEST_PROJECTS[@]}"; do
  echo "dotnet test $test_project -c Release --nologo --no-build"
  run_with_retry dotnet test "$test_project" -c Release --nologo --no-build
done

echo
echo "==> Running vulnerability scan"
for project in "${VULNERABILITY_PROJECTS[@]}"; do
  project_dir="$(dirname "$project")"
  project_file="$(basename "$project")"
  echo "(cd $project_dir && dotnet list $project_file package --vulnerable --include-transitive --config $NUGET_CONFIG)"
  (
    cd "$project_dir"
    run_with_retry dotnet list "$project_file" package --vulnerable --include-transitive --config "$NUGET_CONFIG"
  )
done

if [[ "$RUN_BENCHMARKS" == "1" ]]; then
  if [[ ! -f "$BENCHMARK_SCRIPT" ]]; then
    echo "Benchmark script not found: $BENCHMARK_SCRIPT" >&2
    exit 1
  fi

  echo
  echo "==> Running benchmark suite"
  echo "BENCH_PROFILE=${BENCH_PROFILE:-local} AUTO_HOST=${BENCH_AUTO_HOST:-1} BASE_URL=${BENCH_BASE_URL:-http://127.0.0.1:5000} TOKEN_PATH=${BENCH_TOKEN_PATH:-/connect/token} SCOPE=${BENCH_SCOPE:-resource1.scope1} DURATION=${BENCH_DURATION:-30s} REQUIRE_429=${BENCH_REQUIRE_429:-0} bash $BENCHMARK_SCRIPT"
  run_with_retry env \
    BENCH_PROFILE="${BENCH_PROFILE:-local}" \
    AUTO_HOST="${BENCH_AUTO_HOST:-1}" \
    BASE_URL="${BENCH_BASE_URL:-http://127.0.0.1:5000}" \
    TOKEN_PATH="${BENCH_TOKEN_PATH:-/connect/token}" \
    CLIENT_ID="${BENCH_CLIENT_ID:-client}" \
    CLIENT_SECRET="${BENCH_CLIENT_SECRET:-secret}" \
    SCOPE="${BENCH_SCOPE:-resource1.scope1}" \
    DURATION="${BENCH_DURATION:-30s}" \
    REQUIRE_429="${BENCH_REQUIRE_429:-0}" \
    bash "$BENCHMARK_SCRIPT"
else
  echo
  echo "==> Benchmark suite skipped"
fi

echo
echo "Release verification gate passed."
