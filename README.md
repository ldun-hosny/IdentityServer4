# Ldun Fork Status
This repository is an actively maintained ldun fork of IdentityServer4 for .NET 8 usage and security maintenance.

Published NuGet packages:

- `Ldun.IdentityServer4`
- `Ldun.IdentityServer4.Storage`
- `Ldun.IdentityServer4.AspNetIdentity`
- `Ldun.IdentityServer4.EntityFramework.Storage`
- `Ldun.IdentityServer4.EntityFramework`

The project remains licensed under Apache 2.0.

Historical upstream context: the original IdentityServer4 project moved forward under Duende Software. This fork keeps the IdentityServer4 codebase available for ldun-managed use cases.

## Migrating from the original IdentityServer4 packages

If you are migrating from the upstream `IdentityServer4` NuGet packages:

1. Replace package references:

   | Before | After |
   |--------|-------|
   | `IdentityServer4` | `Ldun.IdentityServer4` |
   | `IdentityServer4.Storage` | `Ldun.IdentityServer4.Storage` |
   | `IdentityServer4.AspNetIdentity` | `Ldun.IdentityServer4.AspNetIdentity` |
   | `IdentityServer4.EntityFramework.Storage` | `Ldun.IdentityServer4.EntityFramework.Storage` |
   | `IdentityServer4.EntityFramework` | `Ldun.IdentityServer4.EntityFramework` |

2. Target **.NET 8** or later — multi-framework targeting (`net6.0`, `net7.0`) is not supported by this fork.

3. **Removed APIs** — the following members were removed; update call sites accordingly:

   | Removed | Replacement |
   |---------|-------------|
   | `PrincipalExtensions.GetSubjectId()` | `PrincipalExtensions.GetDisplayName()` |
   | `PrincipalExtensions.GetName()` | `PrincipalExtensions.GetDisplayName()` |

4. **StrictJarValidation** — this option now emits `Warning`-level log messages for any client
   sending non-conforming JWT authorization request objects (JAR / RFC 9101). Review your logs
   after upgrading and migrate non-conforming clients before enabling strict enforcement:

   ```csharp
   services.AddIdentityServer(options =>
   {
       options.StrictJarValidation = true; // enable after all clients are conformant
   });
   ```

## About IdentityServer4
[<img align="right" width="100px" src="https://dotnetfoundation.org/img/logo_big.svg" />](https://dotnetfoundation.org/projects?searchquery=IdentityServer&type=project)

IdentityServer is a free, open source [OpenID Connect](http://openid.net/connect/) and [OAuth 2.0](https://tools.ietf.org/html/rfc6749) framework for ASP.NET Core.
Founded and maintained by [Dominick Baier](https://twitter.com/leastprivilege) and [Brock Allen](https://twitter.com/brocklallen), IdentityServer4 incorporates all the protocol implementations and extensibility points needed to integrate token-based authentication, single-sign-on and API access control in your applications.
IdentityServer4 is officially [certified](https://openid.net/certification/) by the [OpenID Foundation](https://openid.net) and thus spec-compliant and interoperable.
It is part of the [.NET Foundation](https://www.dotnetfoundation.org/), and operates under their [code of conduct](https://www.dotnetfoundation.org/code-of-conduct). It is licensed under [Apache 2](https://opensource.org/licenses/Apache-2.0) (an OSI approved license).

For project documentation, please visit [readthedocs](https://identityserver4.readthedocs.io).

## Branch structure
Active development happens on the main branch. This always contains the latest version. Each (pre-) release is tagged with the corresponding version. The [aspnetcore1](https://github.com/IdentityServer/IdentityServer4/tree/aspnetcore1) and [aspnetcore2](https://github.com/IdentityServer/IdentityServer4/tree/aspnetcore2) branches contain the latest versions of the older ASP.NET Core based versions.

## How to build

* [Install](https://www.microsoft.com/net/download/core#/current) the latest .NET 8 SDK
* Install Git
* Clone this repo
* Run `build.ps1` or `build.sh` in the root of the cloned repo

## Benchmark and Load Tests

Load and performance validation scripts are available in [`benchmark/`](./benchmark).

Profile-based targets are available:
- `local` default profile: `>= 600` successful tokens/second and `p95 < 700ms`.
- `ci` default profile: `>= 1000` successful tokens/second and `p95 < 250ms`.
- Rate-limit stress scenario included for host/infrastructure DDoS controls.
- Benchmark runner auto-starts local `src/IdentityServer4/host` by default.

Run:

```bash
./benchmark/run.sh
```

Run strict profile locally:

```bash
BENCH_PROFILE=ci ./benchmark/run.sh
```

## Release Validation and Publish

Step 1 - pre-publish verification gate (restore + build + tests + vulnerability scan + optional benchmark):

```bash
RUN_BENCHMARKS=0 ./scripts/verify.sh
```

Step 2 - package all NuGet artifacts:

```bash
./scripts/pack.sh --version 5.0.0 --out /tmp/ids4-pack-5.0.0
```

Step 3 - consumer package E2E gate against pre-packed artifacts:

```bash
./scripts/e2e-consumer.sh --version 5.0.0 --source /tmp/ids4-pack-5.0.0
```

Optional local consumer E2E with auto-pack:

```bash
./scripts/e2e-consumer.sh --version 5.0.0
```

Step 4 - publish prepared artifacts:

```bash
./scripts/publish.sh --version 5.0.0 --out /tmp/ids4-pack-5.0.0
```

Interactive all-in-one orchestrator (prompts for version + NuGet API key and runs all steps):

```bash
./scripts/release.sh
```

Compatibility aliases are still available:
- `./publish-nuget.sh` -> `./scripts/release.sh`
- `./scripts/verify-release.sh` -> `./scripts/verify.sh`

## Documentation
For project documentation, please visit [readthedocs](https://identityserver4.readthedocs.io).

See [here](http://docs.identityserver.io/en/aspnetcore1/) for the 1.x docs, and [here](http://docs.identityserver.io/en/aspnetcore2/) for the 2.x docs.

## Bug reports and feature requests
Please use the [issue tracker](https://github.com/IdentityServer/IdentityServer4/issues) for that. We only support the latest version for free. For older versions, you can get a commercial support agreement with us.

## Commercial and Community Support
If you need help with implementing IdentityServer4 or your security architecture in general, there are both free and commercial support options.
See [here](https://identityserver4.readthedocs.io/en/latest/intro/support.html) for more details.

## Sponsorship
If you are a fan of the project or a company that relies on IdentityServer, you might want to consider sponsoring.
This will help us devote more time to answering questions and doing feature development. If you are interested please head to our [Patreon](https://www.patreon.com/identityserver) page which has further details.

### Platinum Sponsors
[<img src="https://user-images.githubusercontent.com/1454075/62819413-39550c00-bb55-11e9-8f2f-a268c3552c71.png" width="200">](https://udelt.no)

[<img src="https://user-images.githubusercontent.com/1454075/66454740-fb973580-ea68-11e9-9993-6c1014881528.png" width="200">](https://github.com/dotnet-at-microsoft)

### Corporate Sponsors
[Ritter Insurance Marketing](https://www.ritterim.com)  
[ExtraNetUserManager](https://www.extranetusermanager.com/)  
[Knab](https://www.knab.nl/)

You can see a list of our current sponsors [here](https://github.com/IdentityServer/IdentityServer4/blob/main/SPONSORS.md) - and for companies we have some nice advertisement options as well.

## Acknowledgements
IdentityServer4 is built using the following great open source projects and free services:

* [ASP.NET Core](https://github.com/dotnet/aspnetcore)
* [Bullseye](https://github.com/adamralph/bullseye)
* [SimpleExec](https://github.com/adamralph/simple-exec)
* [MinVer](https://github.com/adamralph/minver)
* [Json.Net](http://www.newtonsoft.com/json)
* [XUnit](https://xunit.github.io/)
* [Fluent Assertions](http://www.fluentassertions.com/)
* [GitReleaseManager](https://github.com/GitTools/GitReleaseManager)

..and last but not least a big thanks to all our [contributors](https://github.com/IdentityServer/IdentityServer4/graphs/contributors)!
