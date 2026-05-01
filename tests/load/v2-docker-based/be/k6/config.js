import { sleep } from "k6";

export const BASE_URL = __ENV.BASE_URL || "http://localhost:8080";

// 8개 토큰을 VU 수에 관계없이 순환 사용
const TOKENS = [
  __ENV.TOKEN_1,
  __ENV.TOKEN_2,
  __ENV.TOKEN_3,
  __ENV.TOKEN_4,
  __ENV.TOKEN_5,
  __ENV.TOKEN_6,
  __ENV.TOKEN_7,
  __ENV.TOKEN_8,
];

export function getTokenIndex() {
  return (__VU - 1) % TOKENS.length;
}

export function getHeaders(withAuth = true) {
  const h = { "Content-Type": "application/json" };
  if (withAuth) {
    const token = TOKENS[getTokenIndex()];
    if (token) h["Authorization"] = `Bearer ${token}`;
  }
  return h;
}

export function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// ─────────────────────────────────────────────────────────────
// AI 호출 대체 sleep 함수
// FastAPI 호출 엔드포인트를 테스트에서 제외하는 대신,
// VU가 AI 응답을 기다리는 사용자처럼 동작하도록 대기
// ─────────────────────────────────────────────────────────────
export function sleepFollowUpAI() {
  sleep(randomInt(5, 21)); // 꼬리질문 생성: 5~21초
}

export function sleepPracticeFeedbackAI() {
  sleep(randomInt(10, 20)); // 연습 피드백 생성: 10~20초
}

export function sleepRealFinalFeedbackAI() {
  sleep(randomInt(30, 50)); // 실전 최종 피드백 생성: 30~50초
}

// 가중치 기반 ops 선택기
export function pickOp(ops) {
  const total = ops.reduce((s, o) => s + o.w, 0);
  let r = Math.random() * total;
  for (const o of ops) {
    r -= o.w;
    if (r <= 0) return o.fn;
  }
  return ops[0].fn;
}
