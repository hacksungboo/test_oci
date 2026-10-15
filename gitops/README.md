# Telos GitOps

MoongCheap GitOps 구조를 그대로 따른다.

> **ApplicationSet + 공통 Helm Chart + Values Layering + Service / Platform 분리**

## 1. 동기화 흐름

```
Terraform 02-bootstrap
  └─ Root Application "root"  (path: gitops/argocd, recurse, _prod/ 제외)
       ├─ AppProject telos-platform / telos-services        (sync-wave -2)
       ├─ ApplicationSet telos-platform                     (sync-wave -1)
       │    └─ gitops/platform/**/config.yaml 마다 Helm Application
       │         └─ envoy-gateway  (docker.io/envoyproxy/gateway-helm)
       ├─ Application gateway-resources  -> platform/envoy-gateway/resources
       ├─ Application cloudflared        -> platform/cloudflared
       └─ ApplicationSet telos-services-dev
            └─ web-dev  (charts/telos-service + values layering) -> telos-dev
```

## 2. Values Layering

```
charts/telos-service/values.yaml
  -> values/base.yaml
  -> values/env/<env>.yaml
  -> values/services/<service>.yaml
  -> values/overrides/<env>/<service>.yaml   # CI 가 image.tag 만 갱신
```

## 3. 환경 분리

하나의 클러스터에서 네임스페이스로 나눈다 (MoongCheap 과 동일).

| 환경 | ApplicationSet | Namespace | 상태 |
| --- | --- | --- | --- |
| dev | `argocd/applicationset-services-dev.yaml` | `telos-dev` | 사용 중 |
| prod | `argocd/_prod/applicationset-services-prod.yaml` | `telos-prod` | 미적용 (`_prod/` 밖으로 옮기면 적용) |

Platform(envoy-gateway, cloudflared ...)은 클러스터 공통 한 세트.

## 4. 새 Platform 추가

```
platform/<name>/
├── config.yaml   # name, namespace, helm.repoURL/chart/version
└── values.yaml
```
커밋하면 `applicationset-platform` 이 자동으로 Application 을 만든다. chart 저장소는 `argocd/projects/platform-project.yaml` 의 `sourceRepos` 에 추가.
`platform/_optional/` 아래는 탐색에서 제외된다.

## 5. 호스트 추가 체크리스트

1. Terraform `cloudflare_subdomains` 에 서브도메인 추가 → `terraform apply` (DNS CNAME)
2. `platform/cloudflared/configmap.yaml` ingress 에 hostname 추가 (service 는 항상 `telos-envoy`)
3. `platform/envoy-gateway/resources/httproute-<svc>.yaml` 작성 (hostnames + backendRef)
4. cloudflared 는 ConfigMap 변경을 자동 반영하지 않으므로 `kubectl -n infra rollout restart deploy/cloudflared`
