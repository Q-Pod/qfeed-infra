#!/bin/bash
set -e
source "$(dirname "$0")/common.sh" "$@"

echo "======================================"
echo " Phase 1: 워밍업 확인"
echo " TARGET: $HOST | RESULTS: $RESULTS_DIR"
echo "======================================"

health_check

run_locust "phase1_warmup" 1 1 "5m"

echo ""
echo "✅ Phase 1 완료"
echo "👉 Grafana에서 메모리 수렴값(A: 기준선) 기록 후 Phase 2 진행"
