#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/publish.sh --version <version> --out <dir> [--source <nuget-source>] [--api-key <key>]

Required:
  --version   Package version to publish (example: 5.0.0)
  --out       Directory containing generated .nupkg files

Optional:
  --source    NuGet source URL (default: https://api.nuget.org/v3/index.json)
  --api-key   NuGet API key (if omitted, prompts securely)

Environment:
  RETRY_ATTEMPTS=<n>       Retry attempts per command (default: 2)
  RETRY_DELAY_SECONDS=<n>  Delay between retries (default: 2)
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEFAULT_SOURCE="https://api.nuget.org/v3/index.json"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-2}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-2}"

VERSION=""
OUT=""
SOURCE="$DEFAULT_SOURCE"
NUGET_API_KEY="${NUGET_API_KEY:-}"

PACKAGES=(
  "Ldun.IdentityServer4.Storage"
  "Ldun.IdentityServer4"
  "Ldun.IdentityServer4.AspNetIdentity"
  "Ldun.IdentityServer4.EntityFramework.Storage"
  "Ldun.IdentityServer4.EntityFramework"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --api-key)
      NUGET_API_KEY="${2:-}"
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

if [[ -z "$VERSION" || -z "$OUT" ]]; then
  usage
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid --version value: $VERSION" >&2
  exit 1
fi

if [[ ! -d "$OUT" ]]; then
  echo "Package output directory not found: $OUT" >&2
  exit 1
fi

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

run_with_retry() {
  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi

    if (( attempt >= RETRY_ATTEMPTS )); then
      return 1
    fi

    echo "Command failed (attempt $attempt/$RETRY_ATTEMPTS). Retrying in ${RETRY_DELAY_SECONDS}s."
    attempt=$((attempt + 1))
    sleep "$RETRY_DELAY_SECONDS"
  done
}

if [[ -z "$NUGET_API_KEY" ]]; then
  prompt_secret_masked "NuGet API key: " NUGET_API_KEY
fi

if [[ -z "$NUGET_API_KEY" ]]; then
  echo "NuGet API key is required." >&2
  exit 1
fi

echo "==> Publishing packages from $OUT"
PUBLISHED_PACKAGES=()
for package_id in "${PACKAGES[@]}"; do
  package_path="$OUT/$package_id.$VERSION.nupkg"
  if [[ ! -f "$package_path" ]]; then
    echo "Required package not found: $package_path" >&2
    exit 1
  fi

  echo "dotnet nuget push $package_path --source $SOURCE --api-key *** --skip-duplicate"
  run_with_retry dotnet nuget push "$package_path" --source "$SOURCE" --api-key "$NUGET_API_KEY" --skip-duplicate
  PUBLISHED_PACKAGES+=("$package_path")
done

echo
echo "Publish completed."
echo
echo "Local package files:"
for package_path in "${PUBLISHED_PACKAGES[@]}"; do
  echo "  $package_path"
done

if [[ "$SOURCE" == "$DEFAULT_SOURCE" ]]; then
  echo
  echo "NuGet package pages:"
  for package_id in "${PACKAGES[@]}"; do
    echo "  https://www.nuget.org/packages/$package_id/$VERSION"
  done
fi
