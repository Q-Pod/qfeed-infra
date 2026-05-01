import http from 'k6/http';
import { check, sleep, group, fail } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

// ============================================================
// Q-Feed v2 부하 테스트 스크립트
//
// 경로: 로컬 → CloudFront → ALB → BE:8080 → (AI: mock 서버)
//
// SLO 기준:
//   - 사용자 인터랙션 API: P95 < 3초
//   - 세션 가용성: ≥ 99%
//   - AI 포함 API: P95 기준 제외, 성공률/응답시간 별도 기록
//
// 인증: scripts/generate-tokens.py로 생성한 JWT 토큰 사용
//   - userId 1000~1099, TTL 1시간, DB 조회 없이 서명만 검증
// ============================================================

const BASE_URL = 'https://dev.q-feed.com';

// --- 토큰 파일 로드 (VU 간 공유, 메모리 효율적) ---
const tokens = new SharedArray('tokens', function () {
  return JSON.parse(open('./tokens.json'));
});

// --- 커스텀 메트릭 ---
const interactionDuration = new Trend('interaction_api_duration', true);
const aiDuration = new Trend('ai_api_duration', true);
const interactionErrors = new Rate('interaction_errors');
const aiErrors = new Rate('ai_errors');
const sessionSuccess = new Rate('session_success');

// ============================================================
// 시나리오 선택: K6_SCENARIO 환경변수 (기본: baseline)
// ============================================================
const SCENARIOS = {
  baseline: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 5 },
      { duration: '2m', target: 20 },
      { duration: '2m', target: 50 },
      { duration: '2m', target: 100 },
      { duration: '1m', target: 0 },
    ],
  },
  stress: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 10 },
      { duration: '2m', target: 50 },
      { duration: '2m', target: 100 },
      { duration: '2m', target: 200 },
      { duration: '1m', target: 0 },
    ],
  },
  breaking_point: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 200 },
      { duration: '2m', target: 500 },
      { duration: '2m', target: 1000 },
      { duration: '2m', target: 2000 },
      { duration: '2m', target: 2000 },
      { duration: '1m', target: 0 },
    ],
  },
};

const scenarioName = __ENV.K6_SCENARIO || 'baseline';

export const options = {
  scenarios: {
    default: SCENARIOS[scenarioName],
  },
  thresholds: {
    'interaction_api_duration': ['p(95)<3000'],
    'interaction_errors': ['rate<0.01'],
    'session_success': ['rate>0.99'],
  },
};

// ============================================================
// Setup
// ============================================================
export function setup() {
  if (tokens.length === 0) {
    fail('토큰 파일이 비어있습니다. python3 scripts/generate-tokens.py를 먼저 실행하세요.');
  }
  console.log(`토큰 ${tokens.length}개 로드 완료. 시나리오: ${scenarioName}`);
}

// ============================================================
// 헬퍼: API 호출 + 메트릭 기록
// ============================================================
function callInteractionApi(method, url, body, headers, name) {
  const res = (method === 'GET')
    ? http.get(url, { headers, tags: { name, type: 'interaction' } })
    : http.post(url, body, { headers, tags: { name, type: 'interaction' } });

  interactionDuration.add(res.timings.duration);
  const ok = check(res, {
    [`${name} success`]: (r) => r.status >= 200 && r.status < 300,
  });
  interactionErrors.add(!ok);

  if (res.status === 401) {
    console.warn(`[${name}] Access token 만료 또는 인증 실패.`);
  }

  return res;
}

function callAiApi(url, body, headers, name) {
  const res = http.post(url, body, {
    headers,
    tags: { name, type: 'ai' },
    timeout: '120s',
  });

  aiDuration.add(res.timings.duration);
  const ok = check(res, {
    [`${name} success`]: (r) => r.status >= 200 && r.status < 300,
  });
  aiErrors.add(!ok);

  return res;
}

// ============================================================
// 유저 저니 시뮬레이션
// ============================================================
export default function () {
  // VU마다 다른 토큰 사용 (VU ID 기반으로 순환)
  const tokenData = tokens[__VU % tokens.length];
  const headers = {
    'Authorization': `Bearer ${tokenData.token}`,
    'Content-Type': 'application/json',
  };

  let sessionOk = true;

  // --- 1. 질문 카테고리 + 목록 조회 ---
  group('1. 질문 조회', () => {
    callInteractionApi('GET', `${BASE_URL}/api/questions/categories`, null, headers, 'GET /questions/categories');
    sleep(1);
    callInteractionApi('GET', `${BASE_URL}/api/questions?questionType=CS&page=0&size=10`, null, headers, 'GET /questions');
  });

  sleep(Math.random() + 1);

  // --- 2. 세션 생성 ---
  let sessionId = null;
  let currentQuestion = null;
  let questionType = 'CS';

  group('2. 세션 생성', () => {
    const res = callInteractionApi('POST', `${BASE_URL}/api/interview/sessions`,
      JSON.stringify({ interviewType: 'REAL_INTERVIEW', questionType: 'CS' }),
      headers, 'POST /interview/sessions');

    if (res.status >= 200 && res.status < 300) {
      try {
        const body = JSON.parse(res.body);
        const d = body.data || body;
        sessionId = d.session_id || d.sessionId;
        currentQuestion = d.question_text || d.questionText;
        questionType = d.question_type || d.questionType || 'CS';
      } catch (e) { /* parse error */ }
    }

    if (!sessionId) {
      sessionOk = false;
    }
  });

  sleep(Math.random() + 1);

  // --- 3. 답변 제출 (AI mock 경유) ---
  if (sessionId && currentQuestion) {
    group('3. 답변 제출 (AI)', () => {
      const answerBody = JSON.stringify({
        sessionId: sessionId,
        answerText: '프로세스는 독립된 메모리 공간을 가지고, 스레드는 프로세스 내부의 자원을 공유합니다. 컨텍스트 스위칭 비용은 프로세스가 더 크며, 스레드는 같은 주소 공간을 공유하므로 더 빠릅니다.',
        questionType: questionType,
        question: currentQuestion,
      });

      const res = callAiApi(`${BASE_URL}/api/answers/real`, answerBody, headers, 'POST /answers/real');

      if (res.status >= 200 && res.status < 300) {
        try {
          const body = JSON.parse(res.body);
          const d = body.data || body;
          const nextQ = d.next_question || d.nextQuestion;
          if (nextQ) {
            currentQuestion = nextQ.question_text || nextQ.questionText || currentQuestion;
          }
        } catch (e) { /* parse error */ }
      } else {
        sessionOk = false;
      }
    });
  }

  sleep(Math.random() + 1);

  // --- 4. 학습 통계 + 답변 목록 조회 ---
  group('4. 결과 확인', () => {
    callInteractionApi('GET', `${BASE_URL}/api/users/me/stats`, null, headers, 'GET /users/me/stats');
    sleep(0.5);
    callInteractionApi('GET', `${BASE_URL}/api/answers`, null, headers, 'GET /answers');
  });

  // --- 세션 가용성 기록 ---
  sessionSuccess.add(sessionOk);

  sleep(Math.random() + 1);
}
