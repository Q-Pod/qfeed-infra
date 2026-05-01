#!/bin/bash
set -e

SCRIPTS_DIR="$(dirname "$0")"
export RESULTS_DIR="./results/$(date +%Y%m%d_%H%M%S)"

echo "======================================"
echo " Q-Feed AI 전체 부하테스트 시작"
echo " RESULTS: $RESULTS_DIR"
echo "======================================"

bash "$SCRIPTS_DIR/phase1_warmup.sh" "$@"
echo "⏳ 30초 안정화 대기..."; sleep 30

bash "$SCRIPTS_DIR/phase2_memory.sh" "$@"
echo "⏳ 30초 안정화 대기..."; sleep 30

bash "$SCRIPTS_DIR/phase3_cpu_step.sh" "$@"
echo "⏳ 30초 안정화 대기..."; sleep 30

bash "$SCRIPTS_DIR/phase4_spike.sh" "$@"

echo ""
echo "======================================"
echo " 전체 테스트 완료 | 결과: $RESULTS_DIR"
echo "======================================"
ls -lh "$RESULTS_DIR"
