#!/bin/bash
set -euo pipefail
trap 'echo "ERROR: 배포 실패 (line $LINENO)" >&2' ERR

# --- 사용법 ---
usage() {
  cat <<EOF
사용법: ./deploy-local.sh <EC2_IP> <BE_DIR> <AI_DIR>

  EC2_IP   부하테스트 EC2의 Public IP
  BE_DIR   BE 프로젝트 루트 디렉토리 (Dockerfile이 있는 경로)
  AI_DIR   AI 프로젝트 루트 디렉토리 (Dockerfile이 있는 경로)

옵션:
  -k, --key    SSH 키 경로 (기본: ~/.ssh/qfeed-keypair-2.pem)
  -h, --help   사용법 출력

예시:
  ./deploy-local.sh 3.38.211.146 ~/projects/17-JinyUs-Q-Feed-BE ~/projects/17-JinyUs-Q-Feed-AI
  ./deploy-local.sh -k ~/.ssh/my-key.pem 3.38.211.146 ~/projects/BE ~/projects/AI
EOF
  exit 1
}

# --- 인자 파싱 ---
KEY_PATH="$HOME/.ssh/qfeed-keypair-2.pem"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--key) KEY_PATH="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "알 수 없는 옵션: $1"; usage ;;
    *) break ;;
  esac
done

EC2_IP="${1:?EC2_IP가 필요합니다. ./deploy-local.sh --help 참고}"
BE_DIR="${2:?BE_DIR이 필요합니다. ./deploy-local.sh --help 참고}"
AI_DIR="${3:?AI_DIR이 필요합니다. ./deploy-local.sh --help 참고}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_CMD="ssh -i $KEY_PATH -o StrictHostKeyChecking=no ubuntu@$EC2_IP"
SCP_CMD="scp -i $KEY_PATH -o StrictHostKeyChecking=no"

# --- 검증 ---
echo "=== 부하테스트 배포 시작 ==="
echo "EC2: $EC2_IP"
echo "BE:  $BE_DIR"
echo "AI:  $AI_DIR"
echo "Key: $KEY_PATH"
echo ""

[[ -f "$KEY_PATH" ]] || { echo "ERROR: SSH 키 파일이 없습니다: $KEY_PATH"; exit 1; }
[[ -f "$BE_DIR/Dockerfile" ]] || { echo "ERROR: BE Dockerfile이 없습니다: $BE_DIR/Dockerfile"; exit 1; }
[[ -f "$AI_DIR/Dockerfile" ]] || { echo "ERROR: AI Dockerfile이 없습니다: $AI_DIR/Dockerfile"; exit 1; }

# --- Step 1: BE 이미지 빌드 ---
echo "[1/5] BE 이미지 빌드 중 (--platform linux/arm64)..."
docker build --platform linux/arm64 -t qfeed-backend:loadtest "$BE_DIR"

# --- Step 2: AI 이미지 빌드 ---
echo "[2/5] AI 이미지 빌드 중 (--platform linux/arm64)..."
docker build --platform linux/arm64 -t qfeed-ai:loadtest "$AI_DIR"

# --- Step 3: 이미지 압축 ---
echo "[3/5] 이미지 압축 중..."
TMPDIR=$(mktemp -d)
docker save qfeed-backend:loadtest | gzip > "$TMPDIR/qfeed-backend.tar.gz"
docker save qfeed-ai:loadtest | gzip > "$TMPDIR/qfeed-ai.tar.gz"

BE_SIZE=$(du -h "$TMPDIR/qfeed-backend.tar.gz" | cut -f1)
AI_SIZE=$(du -h "$TMPDIR/qfeed-ai.tar.gz" | cut -f1)
echo "  BE: $BE_SIZE / AI: $AI_SIZE"

# --- Step 4: EC2로 전송 ---
echo "[4/5] EC2로 파일 전송 중..."
$SCP_CMD "$TMPDIR/qfeed-backend.tar.gz" "ubuntu@$EC2_IP:~/loadtest/"
$SCP_CMD "$TMPDIR/qfeed-ai.tar.gz" "ubuntu@$EC2_IP:~/loadtest/"
$SCP_CMD "$SCRIPT_DIR/docker-compose.yml" "ubuntu@$EC2_IP:~/loadtest/"

# .env 파일이 있으면 함께 전송
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  $SCP_CMD "$SCRIPT_DIR/.env" "ubuntu@$EC2_IP:~/loadtest/"
  echo "  .env 파일 전송 완료"
fi

# 임시 파일 정리
rm -rf "$TMPDIR"

# --- Step 5: EC2에서 이미지 로드 + 실행 ---
echo "[5/5] EC2에서 배포 중..."
$SSH_CMD << 'REMOTE'
set -euo pipefail
cd ~/loadtest

echo "이미지 로드 중..."
docker load < qfeed-backend.tar.gz
docker load < qfeed-ai.tar.gz

echo "기존 컨테이너 정리..."
docker compose down 2>/dev/null || true

echo "미사용 이미지 정리..."
docker image prune -f

echo "컨테이너 시작..."
docker compose up -d

echo ""
echo "컨테이너 상태:"
docker compose ps

# 이미지 tar 정리
rm -f qfeed-backend.tar.gz qfeed-ai.tar.gz
REMOTE

echo ""
echo "=== 배포 완료 ==="
echo "BE: http://$EC2_IP:8080"
echo "AI: http://$EC2_IP:8000"
echo ""
echo "SSH 접속: ssh -i $KEY_PATH ubuntu@$EC2_IP"
