# envs/prod (아직 미적용)

dev 테스트가 끝난 뒤 적용한다. 두 가지 방식 중 대회 주제·예산을 보고 고른다.

## A. 클러스터 1개 + 네임스페이스 분리 (MoongCheap 방식, 권장)

- Terraform 은 `envs/dev` 하나만 운영한다 (OKE 1개).
- GitOps 에서 `telos-dev` / `telos-prod` 네임스페이스로 환경을 나눈다.
- 할 일
  1. `gitops/argocd/_prod/applicationset-services-prod.yaml` 을 `gitops/argocd/` 로 옮긴다.
  2. `gitops/values/overrides/prod/<service>.yaml` 의 이미지 태그를 채운다.
  3. prod 호스트(예: `www`)를 `cloudflare_subdomains` 와 `gitops/platform/cloudflared/configmap.yaml`, prod HTTPRoute 에 추가한다.
  4. (선택) MoongCheap 처럼 `develop` 브랜치 = dev, `main` 브랜치 = prod 로 targetRevision 을 나눈다.

## B. 클러스터 2개 (환경별 OKE)

- `envs/dev` 폴더를 통째로 복사해 `envs/prod` 를 만든다.
- 바꿀 값: `variables.tf` 의 `env` 기본값 → `"prod"`, tfvars 의 노드 풀 크기, `cloudflare_subdomains`(dev 와 겹치지 않게), backend key.
- Cloudflare Tunnel 은 환경마다 따로 생긴다 (`telos-prod-oke`).
- 02-bootstrap 의 root app 은 prod 용 경로(예: `gitops/argocd-prod`)를 바라보게 한다.
