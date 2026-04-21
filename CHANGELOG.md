# Changelog

All notable changes to this project are documented in this file.

## [5.0.0] - 2026-04-21

### Summary

This release prepares the ldun fork for modern production use with .NET 8, updated dependency security posture, and safer request-object handling.

### Breaking/Platform Changes

- Target frameworks for publishable packages are now `.NET 8` (`net8.0`).
- Package family uses `Ldun.*` package IDs:
  - `Ldun.IdentityServer4`
  - `Ldun.IdentityServer4.Storage`
  - `Ldun.IdentityServer4.AspNetIdentity`
  - `Ldun.IdentityServer4.EntityFramework.Storage`
  - `Ldun.IdentityServer4.EntityFramework`

### Security and Hardening

- Upgraded `AutoMapper` to `16.1.1`.
- Upgraded IdentityModel dependencies to current non-deprecated versions:
  - `Microsoft.IdentityModel.Protocols.OpenIdConnect` -> `8.17.0`
  - `System.IdentityModel.Tokens.Jwt` -> `8.17.0`
- Added sensitive token masking in trace logging paths to avoid leaking raw token/code values in logs:
  - `AuthorizeEndpointBase`: Identity tokens, authorization codes, access tokens
  - `TokenEndpoint`: Identity tokens, refresh tokens, access tokens
  - `DeviceAuthorizationEndpoint`: Device codes, user codes, verification URIs
- Added `request_uri` pre-validation (`AuthorizeRequestValidator`):
  - Rejects URI fragments
  - Rejects URI userinfo
  - Accepts only `http://` or `https://` schemes (logs warning for insecure `http://`)
  - Returns explicit error for malformed URIs

### Strict JAR Migration Telemetry (non-breaking)

To help teams migrate safely before strict enforcement, this release adds compatibility warnings when `StrictJarValidation` is disabled and incoming requests are accepted but would fail strict mode:

- JWT request object with missing/invalid `typ` header (`JwtRequestValidator`)
- `request_uri` response with non-compliant content type (`DefaultJwtRequestUriHttpClient`)

Additionally, `JwtRequestValidator` now handles `JsonElement.Object` and `JsonElement.Array` values in JWT payloads (for richer request objects).

Behavior is unchanged in this release (warning-only), so existing clients continue to work while you collect remediation data.

### Tests Added

- `SensitiveDataMaskerTests` - Unit tests for token masking
- `DefaultJwtRequestUriHttpClientCompatibilityTelemetryTests` - Telemetry tests
- `AuthorizeRequestValidatorCompatibilityTelemetryTests` - Telemetry tests
- `JwtRequestValidatorCompatibilityTelemetryTests` - Telemetry tests
- Extended `JwtRequestAuthorizeTests` integration tests

### Verification Performed

- Unit tests and integration tests executed successfully for affected areas.
- Publishable projects build successfully in `Release`.
- Dependency vulnerable/deprecated checks executed with no vulnerable/deprecated packages reported for key publishable projects.

### Recommended Rollout

1. Deploy 5.0.0 with `StrictJarValidation = false`.
2. Monitor new compatibility warnings and remediate client integrations.
3. Enable `StrictJarValidation = true` in staging, then canary production.
4. Move to full enforcement after warning volume approaches zero.
