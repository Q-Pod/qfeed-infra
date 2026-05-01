# 부하테스트 Makefile
# 사용법: make help

# --- 설정 (필요시 수정) ---
EC2_IP       ?= 3.39.252.127
EC2_USER     ?= ubuntu
KEY_PATH     ?= ~/.ssh/qfeed-keypair-2.pem
BE_DIR       ?= ~/projects/17-JinyUs-Q-Feed-BE
AI_DIR       ?= ~/projects/17-JinyUs-Q-Feed-AI

SSH_CMD      := ssh -i $(KEY_PATH) -o StrictHostKeyChecking=no $(EC2_USER)@$(EC2_IP)
SCRIPT_DIR   := infra

# =============================================================================
# 인프라
# =============================================================================

.PHONY: setup deploy restart ssh logs ps clean

## EC2 초기 설정 (최초 1회)
setup:
	scp -i $(KEY_PATH) -o StrictHostKeyChecking=no $(SCRIPT_DIR)/setup-ec2.sh $(EC2_USER)@$(EC2_IP):~/
	$(SSH_CMD) "bash ~/setup-ec2.sh"

## 빌드 + 전송 + 배포
deploy:
	$(SCRIPT_DIR)/deploy-local.sh -k $(KEY_PATH) $(EC2_IP) $(BE_DIR) $(AI_DIR)

## .env 변경 후 컨테이너 재시작 (이미지 재빌드 없이)
restart:
	scp -i $(KEY_PATH) -o StrictHostKeyChecking=no $(SCRIPT_DIR)/.env $(EC2_USER)@$(EC2_IP):~/loadtest/.env
	$(SSH_CMD) "cd ~/loadtest && docker compose down && docker compose up -d"

## EC2 SSH 접속
ssh:
	$(SSH_CMD)

## 컨테이너 로그 확인 (서비스 지정: make logs SVC=backend)
logs:
	$(SSH_CMD) "cd ~/loadtest && docker compose logs -f $(SVC)"

## 컨테이너 상태 확인
ps:
	$(SSH_CMD) "cd ~/loadtest && docker compose ps"

## 컨테이너 전체 중지 + 삭제
clean:
	$(SSH_CMD) "cd ~/loadtest && docker compose down -v"

# =============================================================================
# 부하테스트 (k6)
# =============================================================================

.PHONY: smoke load stress

## 스모크 테스트 (빠른 검증)
smoke:
	k6 run k6/smoke.js

## 본 부하테스트
load:
	k6 run k6/load.js

## 스트레스 테스트
stress:
	k6 run k6/stress.js

# =============================================================================
# 도움말
# =============================================================================

.PHONY: help

## 사용 가능한 명령어 목록
help:
	@echo ""
	@echo "사용법: make <명령어> [옵션]"
	@echo ""
	@echo "  [*] 사용 가능  [ ] 미구현  [~] 환경별 설정 필요"
	@echo ""
	@echo "=== 인프라 ==="
	@echo "  [*] setup      EC2 초기 설정 (Docker 설치, 최초 1회)"
	@echo "  [*] deploy     빌드 → 전송 → 배포 (원커맨드)"
	@echo "  [*] ssh        EC2 SSH 접속"
	@echo "  [*] logs       컨테이너 로그 (make logs SVC=backend)"
	@echo "  [*] ps         컨테이너 상태 확인"
	@echo "  [*] restart    .env 변경 후 컨테이너 재시작 (재빌드 없이)"
	@echo "  [*] clean      컨테이너 중지 + 삭제"
	@echo ""
	@echo "=== 부하테스트 ==="
	@echo "  [ ] smoke      스모크 테스트 (k6 스크립트 미작성)"
	@echo "  [ ] load       본 부하테스트 (k6 스크립트 미작성)"
	@echo "  [ ] stress     스트레스 테스트 (k6 스크립트 미작성)"
	@echo ""
	@echo "=== 옵션 ==="
	@echo "  [~] EC2_IP     EC2 IP (기본: $(EC2_IP))"
	@echo "  [~] BE_DIR     BE 프로젝트 경로 (기본: $(BE_DIR))"
	@echo "  [~] AI_DIR     AI 프로젝트 경로 (기본: $(AI_DIR))"
	@echo "  [~] KEY_PATH   SSH 키 경로 (기본: $(KEY_PATH))"
	@echo "  [~] SVC        로그 대상 서비스 (backend, ai, db, redis)"
	@echo ""
	@echo "예시:"
	@echo "  make deploy"
	@echo "  make deploy BE_DIR=~/my-be AI_DIR=~/my-ai"
	@echo "  make logs SVC=backend"
	@echo ""

.DEFAULT_GOAL := help
