## 1. 네이밍 원칙

| 원칙                 | 설명                                           |
| -------------------- | ---------------------------------------------- |
| **소문자 사용**      | 대소문자 혼용 금지, 일관성 유지                |
| **하이픈(-) 구분자** | 단어 구분에 하이픈 사용 (언더스코어 지양)      |
| **의미 있는 이름**   | 리소스 목적과 환경을 즉시 파악 가능하게        |
| **일관성 유지**      | 모든 리소스에 동일한 규칙 적용                 |
| **길이 제한 준수**   | 서비스별 최대 길이 확인 (일반적으로 64자 이내) |

---

## 2. 네이밍 포맷

### 2.1 기본 포맷

`{서비스명}-{환경}-{리소스타입}-{용도}`

### 2.2 구성 요소

| 요소           | 값                             | 설명                        |
| -------------- | ------------------------------ | --------------------------- |
| **서비스명**   | `qfeed`                        | 프로젝트/서비스 식별자      |
| **환경**       | `dev`, `prod`                  | 개발/운영 환경 구분         |
| **리소스타입** | `vpc`, `ec2`, `rds` 등         | AWS 리소스 종류             |
| **용도**       | `backend`, `ai`, `postgres` 등 | 리소스 역할/목적 (2.4 참고) |

### 2.3 환경 코드

| 환경 | 코드   | 설명             |
| ---- | ------ | ---------------- |
| 개발 | `dev`  | 개발/테스트 환경 |
| 운영 | `prod` | 실제 서비스 환경 |

### 2.4 용도 네이밍 기준

| 구분               | 기준              | 예시                             |
| ------------------ | ----------------- | -------------------------------- |
| 서비스 귀속 리소스 | 서비스/컴포넌트명 | `backend`, `ai`, `kafka`         |
| 공유 인프라 리소스 | 리소스 자체 설명  | `rds-postgres`, `rt-private`     |
| 단독 리소스        | 용도 생략         | `qfeed-dev-vpc`, `qfeed-dev-igw` |

- **서비스 귀속**: EC2, SG, ALB, TG, LT, ASG 등 특정 서비스를 위해 존재하는 리소스
- **공유 인프라**: RDS, Route Table 등 여러 서비스가 공유하거나 서비스에 귀속되지 않는 리소스
- **단독**: VPC, IGW, Key Pair 등 환경에 하나만 존재하는 리소스

---

## 3. 리소스별 네이밍 규칙

### 3.1 네트워크

| 리소스           | 포맷                                     | 예시                          |
| ---------------- | ---------------------------------------- | ----------------------------- |
| VPC              | `{서비스명}-{환경}-vpc`                  | `qfeed-prod-vpc`              |
| Subnet (Public)  | `{서비스명}-{환경}-subnet-public-{AZ}`   | `qfeed-prod-subnet-public-a`  |
| Subnet (Private) | `{서비스명}-{환경}-subnet-private-{AZ}`  | `qfeed-prod-subnet-private-a` |
| Internet Gateway | `{서비스명}-{환경}-igw`                  | `qfeed-prod-igw`              |
| NAT Gateway      | `{서비스명}-{환경}-nat-{AZ}`             | `qfeed-prod-nat-a`            |
| Route Table      | `{서비스명}-{환경}-rt-{public\|private}` | `qfeed-prod-rt-public`        |
| Elastic IP       | `{서비스명}-{환경}-eip-{용도}`           | `qfeed-prod-eip-nat`          |

### 3.2 컴퓨팅

| 리소스             | 포맷                                  | 예시                              |
| ------------------ | ------------------------------------- | --------------------------------- |
| EC2 Instance       | `{서비스명}-{환경}-ec2-{용도}`        | `qfeed-prod-ec2-backend`          |
| Security Group     | `{서비스명}-{환경}-sg-{용도}`         | `qfeed-prod-sg-backend`           |
| Key Pair           | `{서비스명}-{환경}-keypair`           | `qfeed-prod-keypair`              |
| AMI                | `{서비스명}-{환경}-ami-{용도}-{날짜}` | `qfeed-prod-ami-backend-20260121` |
| Launch Template    | `{서비스명}-{환경}-lt-{용도}`         | `qfeed-prod-lt-backend`           |
| Auto Scaling Group | `{서비스명}-{환경}-asg-{용도}`        | `qfeed-prod-asg-backend`          |

### 3.3 데이터베이스

| 리소스              | 포맷                                | 예시                         |
| ------------------- | ----------------------------------- | ---------------------------- |
| RDS Instance        | `{서비스명}-{환경}-rds-{엔진}`      | `qfeed-prod-rds-postgres`    |
| RDS Subnet Group    | `{서비스명}-{환경}-rds-subnetgroup` | `qfeed-prod-rds-subnetgroup` |
| RDS Parameter Group | `{서비스명}-{환경}-rds-paramgroup`  | `qfeed-prod-rds-paramgroup`  |
| ElastiCache         | `{서비스명}-{환경}-redis`           | `qfeed-prod-redis`           |

### 3.4 스토리지

| 리소스     | 포맷                           | 예시                  |
| ---------- | ------------------------------ | --------------------- |
| S3 Bucket  | `{서비스명}-{환경}-s3-{용도}`  | `qfeed-prod-s3-audio` |
| EBS Volume | `{서비스명}-{환경}-ebs-{용도}` | `qfeed-prod-ebs-api`  |

※ S3 버킷은 글로벌 고유 이름 필요. 이름 충돌 시에만 계정ID 또는 랜덤 suffix 추가.

### 3.5 로드밸런서

| 리소스       | 포맷                                | 예시                          |
| ------------ | ----------------------------------- | ----------------------------- |
| ALB          | `{서비스명}-{환경}-alb-{용도}`      | `qfeed-prod-alb-backend`      |
| Target Group | `{서비스명}-{환경}-tg-{용도}`       | `qfeed-prod-tg-backend`       |
| Listener     | `{서비스명}-{환경}-listener-{용도}` | `qfeed-prod-listener-backend` |
| NLB          | `{서비스명}-{환경}-nlb-{용도}`      | `qfeed-prod-nlb-backend`      |

### 3.6 DNS / 인증서

| 리소스               | 포맷          | 예시           |
| -------------------- | ------------- | -------------- |
| Route 53 Hosted Zone | 도메인 그대로 | `q-feed.com`   |
| ACM Certificate      | 도메인 그대로 | `*.q-feed.com` |

### 3.7 모니터링 / 로깅

| 리소스               | 포맷                              | 예시                        |
| -------------------- | --------------------------------- | --------------------------- |
| CloudWatch Log Group | `/{서비스명}/{환경}/{컴포넌트}`   | `/qfeed/prod/backend`       |
| CloudWatch Alarm     | `{서비스명}-{환경}-alarm-{지표}`  | `qfeed-prod-alarm-cpu-high` |
| SNS Topic            | `{서비스명}-{환경}-sns-{용도}`    | `qfeed-prod-sns-alert`      |
| Lambda               | `{서비스명}-{환경}-lambda-{용도}` | `qfeed-prod-lambda-discord` |
| CloudWatch Dashboard | `{서비스명}-{환경}-dashboard`     | `qfeed-prod-dashboard`      |

**CloudWatch Log Group 참고:**

- **사용자 정의 로그** (EC2 + CloudWatch Agent): `/{서비스명}/{환경}/{컴포넌트}` 패턴 사용
  - 예: `/qfeed/prod/backend` (Spring Boot), `/qfeed/prod/ai` (FastAPI)
- **AWS 관리형 서비스 로그**: AWS가 자동 생성하므로 `/aws/*` 패턴이 됨
  - 예: `/aws/lambda/qfeed-prod-lambda-discord` (Lambda가 자동 생성)

### 3.8 IAM

| 리소스           | 포맷                               | 예시                              |
| ---------------- | ---------------------------------- | --------------------------------- |
| IAM User         | `{이름}-{역할}`                    | `jiny-cloud`                      |
| IAM Group        | `{서비스명}-{역할}`                | `qfeed-cloud-engineer`            |
| IAM Role         | `{서비스명}-{환경}-role-{용도}`    | `qfeed-prod-role-ec2-backend`     |
| IAM Policy       | `{서비스명}-{환경}-policy-{용도}`  | `qfeed-prod-policy-s3-audio-read` |
| Instance Profile | `{서비스명}-{환경}-profile-{용도}` | `qfeed-prod-profile-ec2-backend`  |

**Role 용도 예시:**

- `ec2-backend`: Backend 서버 (Spring Boot)
- `ec2-ai`: AI 서버 (FastAPI + STT)
- `github-actions`: GitHub Actions CI/CD

---

## 4. 태깅 정책

### 4.1 필수 태그

모든 리소스에 아래 태그를 필수로 적용한다.

| 태그 키       | 값 예시                  | 설명                           |
| ------------- | ------------------------ | ------------------------------ |
| `Name`        | `qfeed-prod-ec2-backend` | 리소스 이름 (네이밍 규칙 준수) |
| `Environment` | `prod`                   | 환경 (dev/prod)                |
| `Project`     | `qfeed`                  | 프로젝트/서비스명              |
| `ManagedBy`   | `terraform`              | 관리 주체 (terraform/manual)   |

### 4.2 EC2 추가 태그

Prometheus `ec2_sd_configs`가 scrape 대상 EC2를 자동 감지할 때 사용하는 태그. 모니터링 대상 EC2에 필수.

| 태그 키 | 값 예시                                | 설명                                                        |
| ------- | -------------------------------------- | ----------------------------------------------------------- |
| `Role`  | `backend`, `ai`, `redis`, `monitoring` | EC2의 역할. Prometheus가 이 태그로 scrape 대상을 필터링한다 |

### 4.3 태그 예시

```
Name: qfeed-prod-ec2-backend
Environment: prod
Project: qfeed
ManagedBy: terraform
```

---

## 5. 서비스별 제약 사항

| 서비스                   | 제약 사항                                                |
| ------------------------ | -------------------------------------------------------- |
| **S3**                   | 글로벌 고유, 3~63자, 소문자/숫자/하이픈만, 마침표 비권장 |
| **EC2**                  | 최대 255자                                               |
| **RDS**                  | 최대 63자, 소문자/숫자/하이픈만, 하이픈으로 시작/끝 불가 |
| **IAM**                  | 최대 64자, 영숫자와 `+=,.@-_` 허용                       |
| **Security Group**       | 최대 255자                                               |
| **CloudWatch Log Group** | 최대 512자, `/`로 계층 구분 가능                         |

---

## **6. 금지 사항**

| 금지 항목                        | 이유                             |
| -------------------------------- | -------------------------------- |
| 대문자 사용                      | 대소문자 혼용으로 인한 혼란 방지 |
| 공백, 특수문자                   | AWS 호환성 문제                  |
| 연속 하이픈 (`--`)               | 가독성 저하                      |
| 하이픈으로 시작/끝               | 일부 서비스에서 허용 안 됨       |
| 개인 식별 정보                   | 보안 이슈                        |
| 의미 없는 이름 (`test1`, `temp`) | 관리 어려움                      |

---

## **7. 체크리스트**

리소스 생성 시 아래 항목을 확인한다.

- [ ] 네이밍 규칙 준수 여부
- [ ] 필수 태그 4개 적용 여부 (Name, Environment, Project, ManagedBy)
- [ ] EC2인 경우: `Role` 태그 적용 여부 (모니터링 대상 EC2)
- [ ] 서비스별 길이/문자 제약 확인
- [ ] 기존 리소스와 이름 충돌 여부
- [ ] 환경(dev/prod) 정확히 구분

---
