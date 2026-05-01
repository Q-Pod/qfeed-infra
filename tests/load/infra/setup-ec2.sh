#!/bin/bash
set -euo pipefail
trap 'echo "ERROR: 설정 실패 (line $LINENO)" >&2' ERR

echo "=== 부하테스트 EC2 초기 설정 ==="

# --- Docker 설치 (Ubuntu 24.04) ---
echo "[1/4] Docker 설치 중..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# --- Docker 서비스 시작 ---
echo "[2/4] Docker 서비스 시작..."
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# --- 작업 디렉토리 생성 ---
echo "[3/4] 작업 디렉토리 생성..."
mkdir -p ~/loadtest

# --- 버전 확인 ---
echo "[4/4] 설치 확인..."
docker --version
docker compose version

echo ""
echo "=== 설정 완료 ==="
echo "docker 그룹 적용을 위해 재접속이 필요합니다:"
echo "   exit 후 다시 SSH 접속하세요."