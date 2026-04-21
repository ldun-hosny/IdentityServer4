import http from "k6/http";
import { check } from "k6";
import { Counter } from "k6/metrics";

const baseUrl = __ENV.BASE_URL || "http://127.0.0.1:5000";
const tokenPath = __ENV.TOKEN_PATH || "/connect/token";
const clientId = __ENV.CLIENT_ID || "client";
const clientSecret = __ENV.CLIENT_SECRET || "secret";
const scope = __ENV.SCOPE || "resource1.scope1";

export const status429 = new Counter("status_429");

export const options = {
  scenarios: {
    rate_limit_stress: {
      executor: "ramping-vus",
      stages: [
        { duration: __ENV.RL_RAMP_DURATION || "10s", target: Number(__ENV.RL_VUS_RAMP || 300) },
        { duration: __ENV.RL_HOLD_DURATION || "20s", target: Number(__ENV.RL_VUS_HOLD || 300) },
        { duration: __ENV.RL_COOLDOWN_DURATION || "10s", target: 0 }
      ]
    }
  },
  thresholds: {
    http_req_failed: ["rate<0.05"],
    checks: ["rate>0.95"]
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

  if (response.status === 429) {
    status429.add(1);
  }

  check(response, {
    "status is handled": (r) =>
      r.status === 200 ||
      r.status === 400 ||
      r.status === 401 ||
      r.status === 429 ||
      r.status === 503
  });
}
