import http from "k6/http";
import { check, sleep } from "k6";
import { BASE_URL, getHeaders } from "./config.js";

export const options = {
  vus: 1,
  duration: "30s",
  thresholds: {
    http_req_failed: ["rate==0"],
  },
};

export default function () {
  const endpoints = [
    { url: `${BASE_URL}/api/questions?size=10` },
    { url: `${BASE_URL}/api/questions/recommendation` },
    { url: `${BASE_URL}/api/answers?limit=10` },
  ];

  for (const ep of endpoints) {
    const res = http.get(ep.url, { headers: getHeaders() });
    check(res, {
      [`${ep.url} → 5xx 아님`]: (r) => r.status < 500,
    });
  }
  sleep(1);
}
