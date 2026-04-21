import http from "k6/http";
import { check } from "k6";
import { Counter, Rate } from "k6/metrics";

const baseUrl = __ENV.BASE_URL || "http://127.0.0.1:5000";
const tokenPath = __ENV.TOKEN_PATH || "/connect/token";
const clientId = __ENV.CLIENT_ID || "client";
const clientSecret = __ENV.CLIENT_SECRET || "secret";
const scope = __ENV.SCOPE || "resource1.scope1";
const p95LatencyMs = Number(__ENV.HTTP_REQ_DURATION_P95_MS || "250");
const successRateThreshold = __ENV.TOKEN_SUCCESS_RATE_THRESHOLD || "0.99";
const httpFailedRateThreshold = __ENV.HTTP_REQ_FAILED_RATE_THRESHOLD || "0.01";

export const tokensIssued = new Counter("tokens_issued");
export const tokenSuccessRate = new Rate("token_success_rate");

export const options = {
  scenarios: {
    token_throughput: {
      executor: "constant-vus",
      vus: Number(__ENV.VUS || 200),
      duration: __ENV.DURATION || "30s"
    }
  },
  thresholds: {
    http_req_failed: [`rate<${httpFailedRateThreshold}`],
    checks: [`rate>${successRateThreshold}`],
    http_req_duration: [`p(95)<${p95LatencyMs}`],
    token_success_rate: [`rate>${successRateThreshold}`]
  }
};

export default function () {
  const payload = [
    "grant_type=client_credentials",
    `client_id=${encodeURIComponent(clientId)}`,
    `client_secret=${encodeURIComponent(clientSecret)}`,
    `scope=${encodeURIComponent(scope)}`
  ].join("&");

  const response = http.post(`${baseUrl}${tokenPath}`, payload, {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    }
  });

  const ok = check(response, {
    "token endpoint returned 200": (r) => r.status === 200,
    "response includes access_token": (r) => {
      if (r.status !== 200) return false;
      try {
        const data = JSON.parse(r.body);
        return typeof data.access_token === "string" && data.access_token.length > 0;
      } catch (_err) {
        return false;
      }
    }
  });

  tokenSuccessRate.add(ok);
  if (ok) {
    tokensIssued.add(1);
  }
}
