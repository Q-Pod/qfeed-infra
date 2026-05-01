from locust import HttpUser, task, between
import os
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv(".env.locust")

# ── Payload 정의 ──────────────────────────────────────────────
AUDIO_URL = os.getenv("AUDIO_URL", "http://localhost:9000/dummy/audio.mp3")

FEEDBACK_PAYLOAD = {
    "user_id": 1,
    "question_id": 1,
    "session_id": "test-session-001",
    "interview_type": "PRACTICE_INTERVIEW",
    "question_type": "CS",
    "interview_history": [
        {
            "question": "프로세스와 스레드의 차이를 설명해주세요.",
            "category": "OS",
            "answer_text": (
                "프로세스는 독립된 메모리 공간을 가지고, "
                "스레드는 프로세스 내 자원을 공유합니다."
            ),
            "turn_type": "new_topic",
            "turn_order": 0,
            "topic_id": 1
        }
    ],
    "keywords": ["메모리", "컨텍스트 스위칭"]
}

QUESTION_PAYLOAD = {
    "user_id": 1,
    "session_id": "test-session-001",
    "question_type": "CS",
    "initial_category": "OS",
    "interview_history": []
}

STT_PAYLOAD = {
    "user_id": 1,
    "session_id": "test-session-001",
    # STT는 audio_url을 받아 앱이 직접 다운로드 후 GPU 서버로 전송
    # 부하테스트용 더미 URL (다운로드 시도 발생 → 실제 S3 or Mock URL 필요)
    "audio_url": AUDIO_URL
}

TTS_PAYLOAD = {
    "user_id": 1,
    "session_id": "test-session-001",
    "text": "네트워크 OSI 7계층에 대해 설명해주세요."
}

# ── 시나리오 ──────────────────────────────────────────────────

class AIServerUser(HttpUser):
    # 실제 사용자의 think-time 모사 (면접 답변 입력 시간)
    wait_time = between(1, 3)

    @task(1)
    def request_feedback(self):
        self.client.post(
            "/ai/interview/feedback/request",
            json=FEEDBACK_PAYLOAD,
            timeout=120
        )

    @task(3)
    def request_question(self):
        self.client.post(
            "/ai/interview/follow-up/questions",
            json=QUESTION_PAYLOAD,
            timeout=60
        )

    @task(3)
    def request_stt(self):
        self.client.post(
            "/ai/stt",
            json=STT_PAYLOAD,
            timeout=30
        )

    @task(3)
    def request_tts(self):
        self.client.post(
            "/ai/tts",
            json=TTS_PAYLOAD,
            timeout=30
        )

    @task(0)
    def health_check(self):
        self.client.get("/ai")
