# Rollout / Rollback 절차

## 1. 배포 전 확인

- 현재 배포 중인 이미지 태그:
  ```bash
  kubectl get deploy -n qfeed-backend-k8s-namespace qfeed-backend-k8s -o jsonpath='{.spec.template.spec.containers[0].image}'
  kubectl get deploy -n qfeed-ai-k8s-namespace qfeed-ai-k8s -o jsonpath='{.spec.template.spec.containers[0].image}'
  ```
- 적용할 overlay 경로: `overlays/prod/backend` 또는 `overlays/prod/ai`

## 2. 배포 실행

```bash
# Backend
kubectl apply -k overlays/prod/backend
kubectl rollout status deployment/qfeed-backend-k8s -n qfeed-backend-k8s-namespace

# AI
kubectl apply -k overlays/prod/ai
kubectl rollout status deployment/qfeed-ai-k8s -n qfeed-ai-k8s-namespace
```

## 3. 롤백

```bash
# Backend
kubectl rollout undo deployment/qfeed-backend-k8s -n qfeed-backend-k8s-namespace

# AI
kubectl rollout undo deployment/qfeed-ai-k8s -n qfeed-ai-k8s-namespace
```

이전 revision 확인:

```bash
kubectl rollout history deployment/qfeed-backend-k8s -n qfeed-backend-k8s-namespace
kubectl rollout history deployment/qfeed-ai-k8s -n qfeed-ai-k8s-namespace
```

## 4. 헬스 확인

- Pod 상태: `kubectl get pods -n qfeed-backend-k8s-namespace -l app=qfeed-backend-k8s`
- NLB/외부에서 API 엔드포인트 호출 검증
