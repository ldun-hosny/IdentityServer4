# Ldun IdentityServer4 Fork

This repository is an actively maintained ldun fork of IdentityServer4 for .NET 8 usage and security maintenance.

IdentityServer4 is an OpenID Connect and OAuth 2.0 framework for ASP.NET Core. This fork is derived from [`cnblogs/IdentityServer4`](https://github.com/cnblogs/IdentityServer4) and the original IdentityServer4 codebase. It is maintained independently for ldun-managed use cases.

The project remains licensed under Apache 2.0.

## Packages

Published NuGet packages:

- `Ldun.IdentityServer4`
- `Ldun.IdentityServer4.Storage`
- `Ldun.IdentityServer4.AspNetIdentity`
- `Ldun.IdentityServer4.EntityFramework.Storage`
- `Ldun.IdentityServer4.EntityFramework`

The project remains licensed under Apache 2.0.

Historical upstream context: the original IdentityServer4 project moved forward under Duende Software. This fork keeps the IdentityServer4 codebase available for ldun-managed use cases.

## Migrating from the original IdentityServer4 packages

If you are migrating from the upstream `IdentityServer4` NuGet packages, replace package references only. Namespace usage in code typically remains `IdentityServer4`.

| Before | After |
|--------|-------|
| `IdentityServer4` | `Ldun.IdentityServer4` |
| `IdentityServer4.Storage` | `Ldun.IdentityServer4.Storage` |
| `IdentityServer4.AspNetIdentity` | `Ldun.IdentityServer4.AspNetIdentity` |
| `IdentityServer4.EntityFramework.Storage` | `Ldun.IdentityServer4.EntityFramework.Storage` |
| `IdentityServer4.EntityFramework` | `Ldun.IdentityServer4.EntityFramework` |

Target .NET 8 or later. Multi-framework targeting for `net6.0` and `net7.0` is not supported by this fork.

### Removed APIs

The following members were removed; update call sites accordingly:

| Removed | Replacement |
|---------|-------------|
| `PrincipalExtensions.GetSubjectId()` | `PrincipalExtensions.GetDisplayName()` |
| `PrincipalExtensions.GetName()` | `PrincipalExtensions.GetDisplayName()` |

### Strict JAR Validation

`StrictJarValidation` emits `Warning`-level log messages for clients sending non-conforming JWT authorization request objects (JAR / RFC 9101). Review logs after upgrading and migrate non-conforming clients before enabling strict enforcement:

```csharp
services.AddIdentityServer(options =>
{
    options.StrictJarValidation = true; // enable after all clients are conformant
});
```

## Build

Install the .NET 8 SDK and Git, then run the platform build script from the repository root:

```bash
./build.sh
```

On Windows:

```powershell
.\build.ps1
```

## Verification

Run the local verification gate before release work:

```bash
./scripts/verify.sh
```

The verification script covers restore, build, tests, vulnerability checks, and optional benchmarks.

Benchmark and load-test details live in [`benchmark/README.md`](./benchmark/README.md).

## Release and Publishing

NuGet publishing is automated through GitHub Actions in [`.github/workflows/publish.yml`](./.github/workflows/publish.yml).

Maintainers should trigger the `Publish NuGet Packages` workflow from a signed `v*` tag or with `workflow_dispatch`. See [`.github/MAINTAINER_PUBLISHING.md`](./.github/MAINTAINER_PUBLISHING.md) for maintainer notes.

Do not put private credentials, internal release procedure, or duplicated workflow internals in this README.

## Documentation

Fork-specific migration notes are available in [`docs/migration/from-identityserver4.rst`](./docs/migration/from-identityserver4.rst).

The broader documentation under [`docs/`](./docs) is inherited from upstream IdentityServer4 and may still contain upstream package names, links, and support references. Treat those pages as technical reference material until they are fully fork-updated.

## Issues and Contributions

Use this repository's issue tracker and pull requests for fork-specific bugs, maintenance work, and documentation fixes.
