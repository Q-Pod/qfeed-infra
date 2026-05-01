# 부하테스트 EC2 배포 가이드

부하테스트용 EC2에 BE + AI + DB + Redis를 docker-compose로 올리는 방법을 안내합니다.

---

## 0. 사전 준비

아래 항목이 로컬 PC에 설치되어 있어야 합니다.

| 항목   | 확인 명령어                     |
| ------ | ------------------------------- |
| Docker | `docker --version`              |
| SSH 키 | `ls ~/.ssh/qfeed-keypair-2.pem` |

SSH 키가 없다면 클라우드 파트에 요청하세요.

---

## 1. Cloud 레포 클론

```bash
git clone https://github.com/100-hours-a-week/17-JinyUs-Q-Feed-Cloud.git
cd 17-JinyUs-Q-Feed-Cloud/tests/load
```

모든 명령어는 `tests/load/` 디렉토리에서 `make`로 실행합니다.

```bash
make help    # 사용 가능한 명령어 목록
```

---

## 2. EC2 초기 설정 (완료됨)

> Docker, Docker Compose 설치가 이미 완료되어 있습니다. 이 단계는 생략해도 됩니다.
>
> EC2를 새로 만든 경우에만 `make setup`을 실행합니다.

---

## 3. 환경변수 설정 (최초 1회)

```bash
cd infra
cp .env.example .env
```

`.env` 파일을 열어서 실제 값을 채워주세요. 대부분 기본값이 설정되어 있으며, 필요에 따라 수정합니다.

주요 항목:

| 항목                     | 기본값           | 설명                   |
| ------------------------ | ---------------- | ---------------------- |
| `POSTGRES_PASSWORD`      | `qfeed-loadtest` | DB 비밀번호            |
| `REDIS_PASSWORD`         | `qfeed-loadtest` | Redis 비밀번호         |
| `JWT_SECRET`             | 더미값           | JWT 시크릿 (32자 이상) |
| `SPRING_PROFILES_ACTIVE` | `loadtest`       | Spring 프로파일        |

> `.env` 파일은 git에 커밋하지 마세요. (`.gitignore`에 포함되어 있습니다)

---

## 4. 배포

```bash
make deploy
```

기본값으로 아래 설정이 사용됩니다:

| 변수       | 기본값                           |
| ---------- | -------------------------------- |
| `EC2_IP`   | `3.39.252.127`                   |
| `BE_DIR`   | `~/projects/17-JinyUs-Q-Feed-BE` |
| `AI_DIR`   | `~/projects/17-JinyUs-Q-Feed-AI` |
| `KEY_PATH` | `~/.ssh/qfeed-keypair-2.pem`     |

기본값과 다른 경우 두 가지 방법으로 변경할 수 있습니다:

1. 명령어에서 직접 덮어쓰기 (일회성):

```bash
make deploy BE_DIR=~/my-be AI_DIR=~/my-ai
make deploy KEY_PATH=~/.ssh/my-key.pem
```

2. `tests/load/Makefile` 상단의 설정값을 직접 수정 (영구 변경):

```makefile
# --- 설정 (필요시 수정) ---
EC2_IP       ?= 3.39.252.127
EC2_USER     ?= ubuntu
KEY_PATH     ?= ~/.ssh/qfeed-keypair-2.pem
BE_DIR       ?= ~/projects/17-JinyUs-Q-Feed-BE
AI_DIR       ?= ~/projects/17-JinyUs-Q-Feed-AI
```

### 내부적으로 수행되는 작업

1. BE/AI 이미지를 `--platform linux/arm64`로 빌드
2. 이미지를 gzip 압축
3. scp로 EC2에 전송
4. EC2에서 docker load + docker compose up

> ARM64 크로스 빌드가 포함되어 있어 첫 빌드는 시간이 걸릴 수 있습니다.

---

## 5. 배포 확인

배포가 완료되면 아래 URL로 확인할 수 있습니다.

| 서비스      | URL                                        |
| ----------- | ------------------------------------------ |
| BE 헬스체크 | `http://3.39.252.127:8080/actuator/health` |
| AI 헬스체크 | `http://3.39.252.127:8000/ai`              |

```bash
make ps                # 컨테이너 상태 확인
make logs SVC=backend  # BE 로그
make logs SVC=ai       # AI 로그
make ssh               # EC2 직접 접속
```

---

## 6. 환경변수(.env) 변경 후 재시작

`.env` 파일을 수정한 후, 이미지 재빌드 없이 컨테이너만 재시작합니다.

```bash
# infra/.env 수정 후
make restart
```

내부적으로 `.env`를 EC2로 전송하고, 컨테이너를 재시작합니다. 코드 변경이 없고 환경변수만 바뀐 경우 이 명령어를 사용하세요.

## 7. 재배포 (코드 변경 시)

코드를 수정한 후 다시 배포하려면 이미지 재빌드가 필요합니다. 기존 컨테이너는 자동으로 정리됩니다.

```bash
make deploy
```

컨테이너만 중지/삭제하려면:

```bash
make clean
```

---

## 7. 부하테스트 EC2 정보

| 항목          | 값                                   |
| ------------- | ------------------------------------ |
| Public IP     | `3.39.252.127`                       |
| Instance ID   | `i-05b61463aa0444d02`                |
| 인스턴스 타입 | t4g.xlarge (4 vCPU, 16GB RAM, ARM64) |
| OS            | Ubuntu 24.04                         |
| SSH 사용자    | `ubuntu`                             |
| 작업 디렉토리 | `~/loadtest`                         |

### 접속 허용 IP

| 팀원        | IP              |
| ----------- | --------------- |
| KTB_guest_1 | 211.244.225.166 |
| KTB_guest_2 | 211.244.225.211 |

본인 IP가 위 목록에 없으면 클라우드 파트에 IP 추가를 요청하세요.

---

## 트러블슈팅

### 1) "Permission denied" (SSH 접속 실패)

```bash
chmod 400 ~/.ssh/qfeed-keypair-2.pem
```

### 2) "Cannot connect to the Docker daemon" (EC2에서)

docker 그룹 적용을 위해 SSH 재접속이 필요합니다. `exit` 후 다시 접속하세요.

### 3) 빌드 시 "platform mismatch" 에러

Docker Desktop에서 멀티 플랫폼 빌드가 활성화되어 있는지 확인하세요:

```bash
docker buildx ls
```

`linux/arm64`가 지원 목록에 없으면:

```bash
docker buildx create --use
```

### 4) 컨테이너는 떴는데 앱이 500 에러 또는 접속 불가

`.env`에 더미값이 들어있으면 컨테이너는 뜨지만 앱이 정상 동작하지 않습니다.

- **BE 500 에러**: JWT_SECRET, DB 연결 정보 등이 유효하지 않을 때 발생
- **AI 접속 불가**: API 키가 누락되면 컨테이너 시작 자체가 실패합니다

`.env` 파일에 실제 값을 채운 후 `make restart`를 실행하세요.

### 5) BE가 `relation "xxx" does not exist` 에러

DB에 테이블이 없어서 발생합니다. 이 docker-compose 환경은 빈 PostgreSQL로 시작하기 때문에 **DDL/마이그레이션이 필요합니다**.

해결 방법 (택 1):

- `.env`에 `SPRING_JPA_HIBERNATE_DDL_AUTO=create` 추가 (Hibernate 자동 생성)
- Flyway/Liquibase 마이그레이션 스크립트를 포함한 이미지 사용
- 초기 스키마 SQL을 수동으로 실행
- 기존 DB의 dump 파일(`pg_dump`)을 EC2로 전송 후 `docker compose exec -T db psql` 로 복원

### 6) AI가 `ENVIRONMENT` validation 에러

`ENVIRONMENT` 값은 `prod`, `dev`, `local` 중 하나여야 합니다. `.env`에서 다른 값(예: `loadtest`)을 넣으면 pydantic validation 에러로 컨테이너가 기동되지 않습니다.

```
# .env
ENVIRONMENT=dev   # prod, dev, local 중 택 1
```

### 7) 컨테이너가 뜨지 않을 때

```bash
ssh -i ~/.ssh/qfeed-keypair-2.pem ubuntu@3.39.252.127
cd ~/loadtest
docker compose logs <서비스명>   # backend, ai, db, redis
```

---

## 폴더 구조

```
tests/load/
├── Makefile              # make 명령어 진입점
├── infra/                # 인프라 세팅 + 배포 스크립트
│   ├── setup-ec2.sh
│   ├── deploy-local.sh
│   ├── docker-compose.yml
│   ├── .env.example
│   └── .env              # (git 제외) 실제 환경변수
├── k6/                   # 부하테스트 시나리오
│   ├── smoke.js
│   ├── load.js
│   └── stress.js
└── results/              # 테스트 결과
    └── ...
```

### k6/ — 부하테스트 스크립트

k6 테스트 시나리오를 이 폴더에 작성합니다.

| 파일        | 용도                                           |
| ----------- | ---------------------------------------------- |
| `smoke.js`  | 스모크 테스트 (최소 트래픽으로 정상 동작 확인) |
| `load.js`   | 본 부하테스트 (목표 트래픽으로 성능 측정)      |
| `stress.js` | 스트레스 테스트 (한계치까지 부하 증가)         |

작성 후 `make smoke`, `make load`, `make stress`로 실행할 수 있습니다.

### results/ — 테스트 결과

부하테스트 실행 결과를 이 폴더에 저장합니다. 예시:

```
results/
├── 2026-03-10-smoke-result.json
├── 2026-03-10-load-result.json
└── 2026-03-10-load-analysis.md      # 분석 리포트
```
