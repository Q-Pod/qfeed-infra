import http from "k6/http";
import { check } from "k6";
import {
  BASE_URL,
  getHeaders,
  randomInt,
  pickOp,
  sleepFollowUpAI,
  sleepPracticeFeedbackAI,
  sleepRealFinalFeedbackAI,
} from "./config.js";

// ── 세션 생성 헬퍼: 헤더를 외부에서 주입받아 동일 토큰 보장 ──
function createPracticeSession(headers) {
  const res = http.post(
    `${BASE_URL}/api/interview/sessions`,
    JSON.stringify({
      interviewType: "PRACTICE_INTERVIEW",
      questionType: "CS",
    }),
    { headers },
  );
  const ok = res.status === 200 || res.status === 201;
  return ok ? res.json("data.session_id") : null;
}

export const options = {
  scenarios: {
    spike: {
      executor: "ramping-arrival-rate",
      startRate: 300,
      timeUnit: "1s",
      preAllocatedVUs: 1000,
      maxVUs: 1200,
      stages: [
        { duration: "3m", target: 300 },
        { duration: "1m", target: 900 },
        { duration: "3m", target: 900 },
        { duration: "2m", target: 300 },
        { duration: "3m", target: 300 },
        { duration: "3m", target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<500"],
  },
};

export default function (data) {
  const headers = getHeaders();

  // ─────────────────────────────────────────────────────────
  // 가중치 분배 (합계 100)
  //
  // 학습 기록 목록 조회 (32%): JPA 다중 조인, 가장 무거운 API
  // 질문 계열 (32%): 서비스 진입점, 호출 빈도 높음
  //     추천(8) + 목록(8) + 상세(8) + 검색(8)
  // 연습 답변 제출 (36%): Write ops, DB INSERT
  // AI 대체 sleep (0%): cpu 상한 측정 목적에 맞지 않으므로 제거
  //     연습피드백(0) + 꼬리질문(0) + 실전피드백(0)
  // ─────────────────────────────────────────────────────────
  const OPS = [
    // ── 학습 기록 목록 조회 ─────────────────────────────────
    {
      w: 32,
      fn: () => {
        const types = ["REAL_INTERVIEW", "PRACTICE_INTERVIEW"];
        const r = http.get(
          `${BASE_URL}/api/answers?limit=10&type=${types[randomInt(0, 1)]}`,
          { headers: getHeaders() },
        );
        check(r, { "answers-list < 500": (res) => res.status < 500 });
      },
    },

    // ── 질문 계열 ───────────────────────────────────────────

    // GET /api/questions/recommendation - 오늘의 추천 질문
    {
      w: 8,
      fn: () => {
        const r = http.get(`${BASE_URL}/api/questions/recommendation`, {
          headers: getHeaders(),
        });
        check(r, { "recommendation < 500": (res) => res.status < 500 });
      },
    },

    // GET /api/questions - 카테고리별 질문 목록
    {
      w: 8,
      fn: () => {
        const r = http.get(
          `${BASE_URL}/api/questions?category=NETWORK&size=10`,
          { headers: getHeaders() },
        );
        check(r, { "question-list < 500": (res) => res.status < 500 });
      },
    },

    // GET /api/questions/1 - 질문 상세
    {
      w: 8,
      fn: () => {
        const r = http.get(`${BASE_URL}/api/questions/1`, {
          headers: getHeaders(),
        });
        check(r, { "question-detail < 500": (res) => res.status < 500 });
      },
    },

    // GET /api/questions/search - 질문 검색
    {
      w: 8,
      fn: () => {
        const r = http.get(
          `${BASE_URL}/api/questions/search?q=${encodeURIComponent("프로토콜")}&size=10`,
          { headers: getHeaders() },
        );
        check(r, { "question-search < 500": (res) => res.status < 500 });
      },
    },

    // ── 연습 모드 답변 제출 ─────────────────────────────────
    {
      w: 36,
      fn: () => {
        // iteration 시작 시 캡처한 headers를 세션 생성과 답변 제출에 동일하게 사용
        const sessionId = createPracticeSession(headers);

        if (!sessionId) {
          console.warn(`VU[${__VU}] session create failed`); // idx 대신 __VU 직접 사용
          return;
        }

        const r = http.post(
          `${BASE_URL}/api/answers/practice`,
          JSON.stringify({
            sessionId,
            questionId: 1,
            answerText: "테스트 답변입니다. ".repeat(15),
          }),
          { headers }, // ← 같은 headers 재사용
        );
        check(r, {
          "practice-submit ok": (res) =>
            res.status === 200 || res.status === 201,
        });
      },
    },

    // ── AI 대체 sleep ────────────────────────────────────────
    { w: 0, fn: () => sleepFollowUpAI() }, // 꼬리질문 대기 (5~21초)
    { w: 0, fn: () => sleepPracticeFeedbackAI() }, // 연습 피드백 대기 (10~20초)
    { w: 0, fn: () => sleepRealFinalFeedbackAI() }, // 실전 피드백 대기 (30~50초)
  ];

  pickOp(OPS)();
}
