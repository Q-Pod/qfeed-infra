#!/usr/bin/env python3
"""
Q-Feed 부하 테스트용 JWT Access Token 생성 스크립트

사용법:
  python3 scripts/generate-tokens.py

필요 패키지:
  pip3 install PyJWT boto3

생성 결과:
  k6/tokens.json — k6 스크립트에서 읽어 VU마다 다른 토큰 사용
"""

import json
import time
import uuid
import sys

try:
    import jwt
    import boto3
except ImportError:
    print("필요 패키지를 설치하세요: pip3 install PyJWT boto3")
    sys.exit(1)

# --- 설정 ---
SSM_PARAM_NAME = "/qfeed/dev/be/JWT_SECRET"
AWS_REGION = "ap-northeast-2"
NUM_USERS = 100           # 생성할 토큰 수
USER_ID_START = 1000      # fake userId 시작값
TOKEN_TTL_SECONDS = 3600  # 1시간
ISSUER = "QFeed"
OUTPUT_FILE = "../tokens.json"

def get_jwt_secret():
    """SSM Parameter Store에서 JWT_SECRET 가져오기"""
    ssm = boto3.client("ssm", region_name=AWS_REGION)
    resp = ssm.get_parameter(Name=SSM_PARAM_NAME, WithDecryption=True)
    return resp["Parameter"]["Value"]

def create_access_token(secret: str, user_id: int) -> str:
    """BE JwtProvider.createAccessToken()과 동일한 구조로 JWT 생성"""
    now = int(time.time())
    payload = {
        "jti": str(uuid.uuid4()),
        "sub": str(user_id),
        "userId": user_id,
        "roles": ["ROLE_USER"],
        "nickname": f"loadtest-{user_id}",
        "type": "ACCESS",
        "iss": ISSUER,
        "iat": now,
        "exp": now + TOKEN_TTL_SECONDS,
    }
    return jwt.encode(payload, secret, algorithm="HS512")

def main():
    print(f"JWT_SECRET 가져오는 중... ({SSM_PARAM_NAME})")
    secret = get_jwt_secret()
    print(f"JWT_SECRET 확인 완료 (길이: {len(secret)})")

    print(f"\n토큰 {NUM_USERS}개 생성 중 (userId: {USER_ID_START}~{USER_ID_START + NUM_USERS - 1}, TTL: {TOKEN_TTL_SECONDS}초)...")
    tokens = []
    for i in range(NUM_USERS):
        user_id = USER_ID_START + i
        token = create_access_token(secret, user_id)
        tokens.append({
            "userId": user_id,
            "token": token,
        })

    with open(OUTPUT_FILE, "w") as f:
        json.dump(tokens, f, indent=2)

    print(f"\n✅ {OUTPUT_FILE}에 {NUM_USERS}개 토큰 저장 완료")
    print(f"   userId 범위: {USER_ID_START} ~ {USER_ID_START + NUM_USERS - 1}")
    print(f"   TTL: {TOKEN_TTL_SECONDS}초 ({TOKEN_TTL_SECONDS // 60}분)")
    print(f"\n⚠️  이 파일은 Git에 커밋하지 마세요!")

if __name__ == "__main__":
    main()
