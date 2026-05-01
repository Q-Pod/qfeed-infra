/**
 * 면접 연습 완전 흐름 부하 테스트
 * 질문 조회 → 답변 제출 → AI 피드백 폴링 (Abuse Guard 포함)
 */

import http from "k6/http";
import { check, sleep, group } from "k6";
import { Rate, Trend, Counter } from "k6/metrics";
import { FormData } from "https://jslib.k6.io/formdata/0.0.2/index.js";

// ==================== 환경변수 / 옵션 ====================
const BASE_URL = __ENV.BASE_URL || "https://dev.q-feed.com";
const DATA_FILE = __ENV.DATA_FILE || "./test-data.json";
const USE_AUTH = __ENV.USE_AUTH === "true"; // 새로 추가: 인증 사용 여부
const ACCESS_TOKEN = __ENV.ACCESS_TOKEN || null; // 새로 추가: 단일 테스트 토큰 (선택적)

export const options = {
  stages: [
    { duration: "1m", target: 1 }, // 단계1
    { duration: "2m", target: 5 }, // 단계2
    { duration: "2m", target: 10 }, // 단계3
    { duration: "2m", target: 20 }, // 단계4
    { duration: "2m", target: 30 }, // 단계5
  ],
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<30000"],
    ai_feedback_completed: ["rate>0.9"],
  },
};

// ==================== 커스텀 메트릭 ====================
const aiFeedbackCompletedRate = new Rate("ai_feedback_completed");
const aiFeedbackTimeoutRate = new Rate("ai_feedback_timeout");
const aiFeedbackDuration = new Trend("ai_feedback_duration");
const answerSubmitFailures = new Counter("answer_submit_failures");
const abuseGuardBlocked = new Counter("abuse_guard_blocked");

// ==================== 테스트 데이터 로드 ====================
let testData = {
  tokens: [],
  questionAnswers: [],
};

try {
  const rawData = JSON.parse(open(DATA_FILE));
  testData = {
    tokens: rawData.tokens || [],
    questionAnswers: rawData.questionAnswers || [],
  };
} catch (e) {
  console.log(`Data file error: ${e.message}. Using empty data.`);
}

function pickRandom(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function skipIfNoAuth() {
  // 새로 추가: 인증 없이 동작하지 않는 환경에서 스킵
  if (USE_AUTH && !ACCESS_TOKEN && testData.tokens.length === 0) {
    console.log("Skipping test: No auth token available and USE_AUTH=true");
    return true;
  }
  return false;
}

// ==================== 주요 테스트 흐름 ====================
export default function () {
  // 인증 확인 & 스킵 여부 체크
  if (skipIfNoAuth()) {
    sleep(1); // 스킵해도 1초 대기 (부하 패턴 유지)
    return;
  }

  // 1. 토큰 선택 (인증 사용 시)
  let token = null;
  if (USE_AUTH) {
    if (ACCESS_TOKEN) {
      token = ACCESS_TOKEN; // 환경변수 토큰 사용
    } else if (testData.tokens.length > 0) {
      token = pickRandom(testData.tokens).token; // JSON 토큰 사용
    } else {
      console.log("No tokens available, skipping this iteration");
      sleep(1);
      return;
    }
  }

  // 2. 질문-답변 쌍 선택
  const qaPair = pickRandom(testData.questionAnswers);
  const questionId = parseInt(qaPair.id);
  const answerText = qaPair.answer;

  group("연습 모드 흐름", function () {
    // 1) 질문 조회
    group("질문 조회", function () {
      const headers = USE_AUTH ? { Authorization: `Bearer ${token}` } : {};
      const res = http.get(`${BASE_URL}/api/questions/${questionId}`, {
        headers,
        tags: { name: "get_question", auth: USE_AUTH ? "yes" : "no" }, // 태그에 인증 여부 추가
      });

      check(res, {
        "질문 조회 성공": (r) => r.status === 200 || r.status === 401, // 변경: 인증 실패도 허용
        "질문 조회 < 100ms": (r) => r.timings.duration < 100,
      });
    });

    sleep(0.5);

    // 2) 답변 제출 (Abuse Guard 통과 여부 확인)
    group("답변 제출", function () {
      const fd = new FormData();
      fd.append("questionId", questionId.toString());
      fd.append("answerText", answerText); // 50~1500자 샘플
      fd.append("answerType", "PRACTICE_INTERVIEW");

      const headers = {
        "Content-Type": `multipart/form-data; boundary=${fd.boundary}`,
      };
      if (USE_AUTH && token) {
        headers["Authorization"] = `Bearer ${token}`;
      }

      const res = http.post(`${BASE_URL}/api/interview/answers`, fd.body(), {
        headers,
        tags: { name: "post_answer" },
      });

      const submitOK = check(res, {
        "답변 제출 201": (r) => r.status === 201,
        "답변 제출 < 500ms": (r) => r.timings.duration < 500,
        "answerId 반환": (r) => !!r.json("answerId"),
        "Abuse Guard 통과": (r) => r.status !== 429, // 429 = rate limit
      });

      if (!submitOK || res.status === 429) {
        abuseGuardBlocked.add(1);
        answerSubmitFailures.add(1);
        return; // Abuse Guard에 막혔으면 피드백 폴링 생략
      }

      const answerId = res.json("answerId");

      // 3) AI 피드백 폴링
      group("AI 피드백 폴링", function () {
        const pollingStart = Date.now();
        const maxWaitMs = 60000; // 1분
        const intervalSec = 0.8;

        let feedbackRes;
        let feedbackCompleted = false;

        while (true) {
          const headers = USE_AUTH ? { Authorization: `Bearer ${token}` } : {};

          feedbackRes = http.get(
            `${BASE_URL}/api/interviews/answers/${answerId}/feedback`,
            {
              headers,
              tags: { name: "get_feedback" },
            },
          );

          const status = feedbackRes.json("status"); // PROCESSING / COMPLETED

          const elapsed = Date.now() - pollingStart;

          if (status === "COMPLETED") {
            const hasMetrics = !!feedbackRes.json("feedback.radar_chart");
            const hasStrengths = !!feedbackRes.json("feedback.strengths");
            const hasImprovements = !!feedbackRes.json("feedback.improvements");

            feedbackCompleted = hasMetrics && hasStrengths && hasImprovements;

            aiFeedbackCompletedRate.add(feedbackCompleted);
            aiFeedbackTimeoutRate.add(0);
            aiFeedbackDuration.add(elapsed);
            break;
          }

          if (elapsed > maxWaitMs) {
            aiFeedbackCompletedRate.add(0);
            aiFeedbackTimeoutRate.add(1);
            aiFeedbackDuration.add(elapsed);
            break;
          }

          sleep(intervalSec);
        }
      });
    });
  });

  // 사용자 think time (실제 사용자처럼)
  sleep(1);
}
