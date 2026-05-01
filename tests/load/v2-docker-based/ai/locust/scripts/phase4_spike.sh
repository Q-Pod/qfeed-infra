#!/bin/bash
set -e
source "$(dirname "$0")/common.sh" "$@"

# Phase 3에서 확인한 safe VU의 3배로 설정 (기본값 150)
SPIKE_USERS=${SPIKE_USERS:-30}

echo "======================================"
echo " Phase 4: 스파이크 테스트"
echo " SPIKE_USERS: $SPIKE_USERS"
echo " TARGET: $HOST | RESULTS: $RESULTS_DIR"
echo "======================================"

health_check

run_locust "phase4_spike" "$SPIKE_USERS" 20 "10m"

echo ""
echo "✅ Phase 4 완료"
echo "👉 확인 항목:"
echo "   - 스파이크 구간 메모리 최대값(B') 기록"
echo "   - 스파이크 후 메모리 회복 여부 (누수 없음 확인)"
