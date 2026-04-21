#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/e2e-consumer.sh --version <version> [--source <local-package-dir>] [--auto-pack] [--pack-out <dir>] [--workdir <dir>] [--skip-runtime]

Required:
  --version    Package version to validate (example: 5.0.0)

Optional:
  --source       Local directory containing generated .nupkg files
  --auto-pack    Build/pack all Ldun packages locally before E2E (auto-enabled when --source is omitted)
  --pack-out     Output directory for auto-packed .nupkg files (default: <workdir>/packed)
  --workdir      Working directory for generated consumer apps (default: /tmp/ids4-consumer-e2e-<pid>)
  --skip-runtime Skip runtime host/token smoke test and run compile/install smoke only

Environment:
  KEEP_E2E_WORKDIR=1   Keep the generated work directory for inspection
  E2E_PORT=<port>      Port for runtime smoke app (default: 5905)
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-2}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-2}"
ASPNETCORE_VERSION="${ASPNETCORE_VERSION:-8.0.26}"
EFCORE_VERSION="${EFCORE_VERSION:-8.0.26}"

VERSION=""
SOURCE_DIR=""
WORK_DIR=""
SKIP_RUNTIME=0
AUTO_PACK=0
PACK_OUT=""

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
    --source)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    --auto-pack)
      AUTO_PACK=1
      shift
      ;;
    --pack-out)
      PACK_OUT="${2:-}"
      shift 2
      ;;
    --workdir)
      WORK_DIR="${2:-}"
      shift 2
      ;;
    --skip-runtime)
      SKIP_RUNTIME=1
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

if [[ "$AUTO_PACK" == "1" && -n "$SOURCE_DIR" ]]; then
  echo "--auto-pack and --source cannot be used together." >&2
  exit 1
fi

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="/tmp/ids4-consumer-e2e-$$"
fi

mkdir -p "$WORK_DIR"

APP_PID=""
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

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi

  if [[ "${KEEP_E2E_WORKDIR:-0}" != "1" ]]; then
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

if [[ -z "$SOURCE_DIR" ]]; then
  AUTO_PACK=1
fi

if [[ "$AUTO_PACK" == "1" ]]; then
  PACK_OUT="${PACK_OUT:-$WORK_DIR/packed}"
  mkdir -p "$PACK_OUT"

  echo "==> Auto-packing local packages to $PACK_OUT"
  for item in "${PACK_ITEMS[@]}"; do
    IFS='|' read -r module_dir project_path package_id pack_extra <<< "$item"
    (
      cd "$ROOT_DIR/$module_dir"
      run_with_retry dotnet build "$project_path" -c Release --nologo
      if [[ -n "$pack_extra" ]]; then
        run_with_retry dotnet pack "$project_path" -c Release -o "$PACK_OUT" --no-build -p:MinVerVersionOverride="$VERSION" "$pack_extra" -v minimal
      else
        run_with_retry dotnet pack "$project_path" -c Release -o "$PACK_OUT" --no-build -p:MinVerVersionOverride="$VERSION" -v minimal
      fi
    )

    packed_path="$PACK_OUT/$package_id.$VERSION.nupkg"
    if [[ ! -f "$packed_path" ]]; then
      echo "Expected packed package not found: $packed_path" >&2
      exit 1
    fi
  done

  SOURCE_DIR="$PACK_OUT"
else
  if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Package source directory not found: $SOURCE_DIR" >&2
    exit 1
  fi
fi

NUGET_CONFIG="$WORK_DIR/NuGet.config"
cat > "$NUGET_CONFIG" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="$SOURCE_DIR" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
EOF

PACKAGES=(
  "Ldun.IdentityServer4.Storage"
  "Ldun.IdentityServer4"
  "Ldun.IdentityServer4.AspNetIdentity"
  "Ldun.IdentityServer4.EntityFramework.Storage"
  "Ldun.IdentityServer4.EntityFramework"
)

echo "==> Validating local package files exist"
for package_id in "${PACKAGES[@]}"; do
  package_path="$SOURCE_DIR/$package_id.$VERSION.nupkg"
  if [[ ! -f "$package_path" ]]; then
    echo "Required package not found: $package_path" >&2
    exit 1
  fi
done

echo
echo "==> Compile/install smoke test for each package"
for package_id in "${PACKAGES[@]}"; do
  project_dir="$WORK_DIR/smoke-${package_id//./-}"
  mkdir -p "$project_dir"
  (
    cd "$project_dir"
    run_with_retry dotnet new classlib --framework net8.0 --name SmokeApp --force >/dev/null
    run_with_retry dotnet add SmokeApp/SmokeApp.csproj package "$package_id" --version "$VERSION" --source "$SOURCE_DIR" --no-restore
    run_with_retry dotnet restore SmokeApp/SmokeApp.csproj --configfile "$NUGET_CONFIG" --nologo
    run_with_retry dotnet build SmokeApp/SmokeApp.csproj -c Release --no-restore --nologo
  )
done

if [[ "$SKIP_RUNTIME" == "1" ]]; then
  echo
  echo "Runtime smoke test skipped."
  echo "Consumer E2E gate passed."
  exit 0
fi

echo
echo "==> Runtime smoke test for AspNetIdentity consumer flow"
RUNTIME_DIR="$WORK_DIR/runtime-app"
mkdir -p "$RUNTIME_DIR"

(
  cd "$RUNTIME_DIR"
  run_with_retry dotnet new web --framework net8.0 --name RuntimeApp --force >/dev/null

  run_with_retry dotnet add RuntimeApp/RuntimeApp.csproj package Ldun.IdentityServer4.AspNetIdentity --version "$VERSION" --source "$SOURCE_DIR" --no-restore
  run_with_retry dotnet add RuntimeApp/RuntimeApp.csproj package Microsoft.AspNetCore.Identity.EntityFrameworkCore --version "$ASPNETCORE_VERSION" --no-restore
  run_with_retry dotnet add RuntimeApp/RuntimeApp.csproj package Microsoft.EntityFrameworkCore.InMemory --version "$EFCORE_VERSION" --no-restore

  cat > RuntimeApp/AppDbContext.cs <<'EOF'
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace RuntimeApp;

public sealed class AppDbContext : IdentityDbContext<IdentityUser, IdentityRole, string>
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }
}
EOF

  cat > RuntimeApp/Program.cs <<'EOF'
using IdentityServer4;
using IdentityServer4.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RuntimeApp;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseInMemoryDatabase("ids4-e2e"));

builder.Services
    .AddIdentity<IdentityUser, IdentityRole>()
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

builder.Services
    .AddIdentityServer()
    .AddDeveloperSigningCredential()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new("api1")
    })
    .AddInMemoryClients(new Client[]
    {
        new()
        {
            ClientId = "client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    })
    .AddAspNetIdentity<IdentityUser>();

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => Results.Ok("ready"));
app.Run();
EOF

  run_with_retry dotnet restore RuntimeApp/RuntimeApp.csproj --configfile "$NUGET_CONFIG" --nologo
  run_with_retry dotnet build RuntimeApp/RuntimeApp.csproj -c Release --no-restore --nologo
)

PORT="${E2E_PORT:-5905}"
BASE_URL="http://127.0.0.1:$PORT"
RUNTIME_LOG="$WORK_DIR/runtime-app.log"

(
  cd "$RUNTIME_DIR/RuntimeApp"
  ASPNETCORE_URLS="$BASE_URL" dotnet run -c Release --no-build --no-launch-profile
) > "$RUNTIME_LOG" 2>&1 &
APP_PID=$!

wait_for_oidc() {
  local attempts=90
  local i=0
  while [[ "$i" -lt "$attempts" ]]; do
    if curl -fsS "$BASE_URL/.well-known/openid-configuration" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

if ! wait_for_oidc; then
  echo "Runtime smoke app failed to start at $BASE_URL" >&2
  echo "Runtime log (tail):" >&2
  tail -n 100 "$RUNTIME_LOG" >&2 || true
  exit 1
fi

TOKEN_JSON="$WORK_DIR/token-response.json"
HTTP_CODE="$(curl -sS -o "$TOKEN_JSON" -w '%{http_code}' \
  -X POST "$BASE_URL/connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials&client_id=client&client_secret=secret&scope=api1')"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Token endpoint smoke test failed. HTTP $HTTP_CODE" >&2
  cat "$TOKEN_JSON" >&2 || true
  exit 1
fi

if ! jq -e '.access_token and .token_type == "Bearer"' "$TOKEN_JSON" >/dev/null; then
  echo "Token response missing expected fields" >&2
  cat "$TOKEN_JSON" >&2 || true
  exit 1
fi

echo
echo "Consumer E2E gate passed."
if [[ "${KEEP_E2E_WORKDIR:-0}" == "1" ]]; then
  echo "Kept workdir: $WORK_DIR"
fi
if [[ "$AUTO_PACK" == "1" ]]; then
  echo "Packed packages directory: $SOURCE_DIR"
fi
