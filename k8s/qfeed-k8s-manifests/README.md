# qfeed-k8s-manifests

Kustomize 기반 Backend / AI 배포 manifest 저장소.

- **base**: 공통 Deployment, Service, PDB
- **overlays/prod**: prod 환경용 이미지 태그 등 오버레이
- **docs**: rollout/rollback, kustomize 이미지 사용법

## 적용

```bash
# Backend
kubectl apply -k overlays/prod/backend

# AI
kubectl apply -k overlays/prod/ai
```

Backend는 ESO로 동기화된 Secret `qfeed-backend-k8s-secret`을 사용합니다. Step 6/7 런북 참고.
