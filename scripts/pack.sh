#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/pack.sh --version <version> [--out <dir>] [--rebuild]

Required:
  --version   Package version to pack (example: 5.0.0)

Optional:
  --out       Output folder for .nupkg files (default: /tmp/ids4-pack-<version>)
  --rebuild   Build each project before packing (default: off)

Environment:
  RETRY_ATTEMPTS=<n>       Retry attempts per command (default: 2)
  RETRY_DELAY_SECONDS=<n>  Delay between retries (default: 2)
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-2}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-2}"

VERSION=""
OUT=""
REBUILD=0

PACK_ITEMS=(
  "src/Storage|./src/IdentityServer4.Storage.csproj|Ldun.IdentityServer4.Storage|"
  "src/IdentityServer4|./src/IdentityServer4.csproj|Ldun.IdentityServer4|"
  "src/AspNetIdentity|./src/IdentityServer4.AspNetIdentity.csproj|Ldun.IdentityServer4.AspNetIdentity|-p:DisableTransitiveProjectReferences=true"
  "src/EntityFramework.Storage|./src/IdentityServer4.EntityFramework.Storage.csproj|Ldun.IdentityServer4.EntityFramework.Storage|"
  "src/EntityFramework|./src/IdentityServer4.EntityFramework.csproj|Ldun.IdentityServer4.EntityFramework|"
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
    --rebuild)
      REBUILD=1
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
  usage
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid --version value: $VERSION" >&2
  exit 1
fi

if [[ -z "$OUT" ]]; then
  OUT="/tmp/ids4-pack-$VERSION"
fi

if [[ "$OUT" != /* ]]; then
  OUT="$ROOT_DIR/$OUT"
fi

rm -rf "$OUT"
mkdir -p "$OUT"

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

echo "==> Packing NuGet packages"
for item in "${PACK_ITEMS[@]}"; do
  IFS='|' read -r module_dir project_path package_id pack_extra <<< "$item"
  (
    cd "$ROOT_DIR/$module_dir"

    if [[ "$REBUILD" == "1" ]]; then
      echo "cd $module_dir && dotnet build $project_path -c Release --nologo"
      run_with_retry dotnet build "$project_path" -c Release --nologo
    fi

    if [[ -n "$pack_extra" ]]; then
      if [[ "$REBUILD" == "1" ]]; then
        echo "cd $module_dir && dotnet pack $project_path -c Release -o $OUT --no-build -p:MinVerVersionOverride=$VERSION $pack_extra -v minimal"
        run_with_retry dotnet pack "$project_path" -c Release -o "$OUT" --no-build -p:MinVerVersionOverride="$VERSION" "$pack_extra" -v minimal
      else
        echo "cd $module_dir && dotnet pack $project_path -c Release -o $OUT --no-build --no-restore -p:MinVerVersionOverride=$VERSION $pack_extra -v minimal"
        run_with_retry dotnet pack "$project_path" -c Release -o "$OUT" --no-build --no-restore -p:MinVerVersionOverride="$VERSION" "$pack_extra" -v minimal
      fi
    else
      if [[ "$REBUILD" == "1" ]]; then
        echo "cd $module_dir && dotnet pack $project_path -c Release -o $OUT --no-build -p:MinVerVersionOverride=$VERSION -v minimal"
        run_with_retry dotnet pack "$project_path" -c Release -o "$OUT" --no-build -p:MinVerVersionOverride="$VERSION" -v minimal
      else
        echo "cd $module_dir && dotnet pack $project_path -c Release -o $OUT --no-build --no-restore -p:MinVerVersionOverride=$VERSION -v minimal"
        run_with_retry dotnet pack "$project_path" -c Release -o "$OUT" --no-build --no-restore -p:MinVerVersionOverride="$VERSION" -v minimal
      fi
    fi
  )

  package_path="$OUT/$package_id.$VERSION.nupkg"
  if [[ ! -f "$package_path" ]]; then
    echo "Expected package not found: $package_path" >&2
    exit 1
  fi
done

echo
echo "Pack completed."
echo "Package files:"
for item in "${PACK_ITEMS[@]}"; do
  IFS='|' read -r _module_dir _project_path package_id _pack_extra <<< "$item"
  echo "  $OUT/$package_id.$VERSION.nupkg"
done
