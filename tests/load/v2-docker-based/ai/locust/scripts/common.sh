#!/bin/bash
# 공통 환경변수 및 함수

ENV_FILE="../.env.locust"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "❌ .env.locust 파일이 없습니다."
  exit 1
fi

HOST=${1:-$TARGET_HOST}
RESULTS_DIR=${RESULTS_DIR:-"../results/$(date +%Y%m%d_%H%M%S)"}
mkdir -p "$RESULTS_DIR"

run_locust() {
  local label=$1
  local users=$2
  local spawn_rate=$3
  local run_time=$4

  echo ""
  echo "  → $label | ${users} VU / ${run_time}"
  locust -f ../locustfile.py --headless \
    --users "$users" \
    --spawn-rate "$spawn_rate" \
    --run-time "$run_time" \
    --host "$HOST" \
    --csv="$RESULTS_DIR/$label"
  echo "  ✅ $label 완료"
}

health_check() {
  echo "[사전확인] 앱 헬스체크..."
  if ! curl -sf "$HOST/ai" > /dev/null; then
    echo "❌ 앱이 응답하지 않습니다. 컨테이너 상태를 확인하세요."
    exit 1
  fi
  echo "✅ 앱 정상 응답 확인"
}
