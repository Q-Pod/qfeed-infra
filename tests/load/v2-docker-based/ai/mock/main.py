import asyncio
import time
import json
import random
from fastapi import FastAPI, Request
from fastapi.responses import Response

app = FastAPI()

# 요청마다 범위 내 랜덤 지연을 주는 함수
def llm_delay() -> float:
    return random.choice([random.uniform(5.0, 21.0), random.uniform(15.0, 53.0)])

def stt_delay() -> float:
    return random.uniform(0.3, 2.0)

def tts_delay() -> float:
    return random.uniform(0.3, 3.0)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/v1/chat/completions")
async def mock_vllm(request: Request):
    body = await request.json()
    await asyncio.sleep(llm_delay())

    # structured_outputs의 properties를 보고 분기
    schema = body.get("structured_outputs", {}).get("json", {})
    props = set(schema.get("properties", {}).keys())

    # feedback_generator → OverallFeedback
    if {"strengths", "improvements"}.issubset(props):
        content = json.dumps({
            "strengths": "핵심 개념을 명확하게 설명했으며 비교 분석이 논리적이었습니다.",
            "improvements": "구체적인 예시를 추가하면 더 설득력 있는 답변이 될 것입니다."
        })

    # rubric_evaluator → RubricEvaluationResult
    elif {"accuracy", "logic", "specificity", "completeness", "delivery"}.issubset(props):
        content = json.dumps({
            "accuracy": 4,
            "logic": 3,
            "specificity": 3,
            "completeness": 4,
            "delivery": 4
        })

    # follow_up_generator → FollowUpOutput (cushion_text, question_text, subcategory)
    elif {"cushion_text", "question_text", "subcategory"}.issubset(props):
        content = json.dumps({
            "cushion_text": "좋습니다, 다음 질문입니다.",
            "question_text": "스레드와 프로세스의 컨텍스트 스위칭 차이를 설명해주세요.",
            "subcategory": "OS"
        })

    # portfolio_follow_up_generator → PortfolioFollowUpOutput (cushion_text, question_text)
    elif {"cushion_text", "question_text"}.issubset(props) and "decision" not in props:
        content = json.dumps({
            "cushion_text": "좋습니다, 다음 질문입니다.",
            "question_text": "해당 프로젝트에서 가장 어려웠던 기술적 의사결정을 설명해주세요."
        })

    # question_router → QuestionOutput (decision, reasoning, ...)
    else:
        content = json.dumps({
            "decision": "new_topic",
            "reasoning": "mock",
            "question_text": "스레드와 프로세스의 컨텍스트 스위칭 차이를 설명해주세요.",
            "category": "OS",
            "cushion_text": "좋습니다, 다음 질문입니다."
        })

    return {
        "id": "mock-vllm-001",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": "mock-vllm",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": content},
            "finish_reason": "stop"
        }],
        "usage": {"prompt_tokens": 150, "completion_tokens": 60, "total_tokens": 210}
    }


@app.post("/whisper/stt")
async def mock_stt(request: Request):
    await asyncio.sleep(stt_delay())
    return {
        "text": "프로세스는 독립된 메모리 공간을 가지고 스레드는 해당 공간을 공유합니다.",
        "duration": 3.2,
        "processing_time_ms": 148.5
    }


@app.post("/v1/text-to-speech/{voice_id}")
async def mock_tts(voice_id: str, request: Request):
    await asyncio.sleep(tts_delay())
    dummy_audio = b"ID3" + b"\x00" * 128
    return Response(content=dummy_audio, media_type="audio/mpeg")


@app.get("/dummy/audio.mp3")
async def mock_audio_file():
    dummy_mp3 = b"ID3" + b"\x00" * 256
    return Response(content=dummy_mp3, media_type="audio/mpeg")
