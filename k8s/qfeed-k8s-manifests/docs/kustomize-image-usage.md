# kustomize edit set image 사용법

## 이미지 태그만 변경 후 배포

1. overlay 디렉터리로 이동:
   ```bash
   cd overlays/prod/backend   # 또는 overlays/prod/ai
   ```
2. 이미지 태그 설정:
   ```bash
   kustomize edit set image 092399857215.dkr.ecr.ap-northeast-2.amazonaws.com/qfeed-ecr-backend:NEW_TAG
   ```
3. 적용:
   ```bash
   kubectl apply -k .
   ```

## CI 파이프라인에서 사용

- `kustomize build overlays/prod/backend` 후 `kubectl apply -f -` 로 한 번에 적용
- 이미지 태그는 CI 변수로 주입 후 `kustomize edit set image ...` 또는 `kustomization.yaml`의 `images[].newTag`를 치환
