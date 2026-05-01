#!/bin/bash
set -e
source "$(dirname "$0")/common.sh" "$@"

echo "======================================"
echo " Phase 2: 메모리 관찰 테스트"
echo " TARGET: $HOST | RESULTS: $RESULTS_DIR"
echo "======================================"

health_check

run_locust "phase2_memory" 10 2 "30m"

echo ""
echo "✅ Phase 2 완료"
echo "👉 확인 항목:"
echo "   - 메모리 완전 평탄 수렴값(A) 기록"
echo "   - 메모리가 계속 오르면 누수 의심 → 원인 파악 후 재테스트"
