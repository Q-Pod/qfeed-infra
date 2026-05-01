#!/bin/bash
set -e
source "$(dirname "$0")/common.sh" "$@"

echo "======================================"
echo " Phase 3: CPU 스텝 테스트"
echo " TARGET: $HOST | RESULTS: $RESULTS_DIR"
echo "======================================"

health_check

for USERS in 10 20 30 40 50; do
  run_locust "phase3_${USERS}u" "$USERS" 3 "5m" || true
  echo "  ⏳ 30초 안정화 대기..."
  sleep 30
done

echo ""
echo "✅ Phase 3 완료"
echo "👉 확인 항목:"
echo "   - p95 응답시간 급등 지점 → safe VU 상한선 결정"
echo "   - safe VU 구간 CPU p90(C) 기록"
echo "   - 에러율 0% 유지 여부 확인"
