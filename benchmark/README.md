# Benchmark and Load Tests

This directory contains endpoint-level performance and stress tests for the ldun fork.

## Goals

- Establish and track token issuance throughput baseline.
- Make rate-limit and burst behavior visible before release.

## Throughput Target

`run.sh` uses benchmark profiles from `targets.json`:

- `local` profile (default on developer machines): `>= 600` successful tokens/second and `p95 < 700ms`.
- `ci` profile (default when `CI=true` or `GITHUB_ACTIONS` is set): `>= 1000` successful tokens/second and `p95 < 250ms`.

Throughput script thresholds are also enforced:

- `http_req_failed < 1%`
- `checks > 99%`
- `token_success_rate > 99%`

## Files

- `targets.json`: throughput and stress targets used by `run.sh`.
- `k6/token-throughput.js`: token endpoint throughput load test.
- `k6/rate-limit-stress.js`: burst stress test to validate host-level rate limiting behavior.
- `run.sh`: convenience wrapper that runs both tests and enforces targets.

## Prerequisites

- `k6`
- `jq`
- `curl`

By default, the runner auto-starts the local host project:

- `src/IdentityServer4/host/Host.csproj`

Default benchmark credentials/scope are aligned with the sample host:

- `CLIENT_ID=client`
- `CLIENT_SECRET=secret`
- `SCOPE=resource1.scope1`

## Quick Start

```bash
./benchmark/run.sh
```

Run strict CI profile locally:

```bash
BENCH_PROFILE=ci ./benchmark/run.sh
```

Optional target overrides:

- `MIN_TPS` to override throughput target.
- `HTTP_REQ_DURATION_P95_MS` or `MAX_P95_LATENCY_MS` to override p95 latency target.
- `MIN_429_REQUIRED` to override required `429` count when `REQUIRE_429=1`.

## External Host Mode

If you already run IdentityServer elsewhere, disable auto-host:

```bash
AUTO_HOST=0 \
BASE_URL="https://localhost:5001" \
TOKEN_PATH="/connect/token" \
CLIENT_ID="your_client" \
CLIENT_SECRET="your_secret" \
SCOPE="your_scope" \
./benchmark/run.sh
```

## Notes on Rate Limiting

IdentityServer itself does not enforce global DDoS controls. Rate limiting is generally applied in host middleware and infrastructure (ASP.NET Core rate limiter, reverse proxy, WAF, CDN).

Use `REQUIRE_429=1` in `run.sh` to fail if no `429` responses are observed during stress.

Fast local smoke run example:

```bash
DURATION=5s \
VUS=20 \
RL_VUS_RAMP=50 \
RL_VUS_HOLD=50 \
RL_RAMP_DURATION=3s \
RL_HOLD_DURATION=5s \
RL_COOLDOWN_DURATION=3s \
./benchmark/run.sh
```
