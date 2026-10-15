# test_oci — OCI(OKE) + ArgoCD GitOps 뼈대

Oracle TELOS Challenge 대비용. MoongCheap(Terraform 모듈 + ApplicationSet + 공통 Helm Chart + Values Layering)과
Jit-Hub(레이어 분리 Terraform, cloudflared, GitHub Actions)의 방식을 그대로 OCI 로 옮긴 뼈대다.

목표: `terraform apply` 두 번으로 OKE 를 띄우고, ArgoCD 가 nginx 테스트 페이지를 **https://ccmall.shop** 에 배포한다.

```
사용자 ──HTTPS──> Cloudflare Edge (ccmall.shop, argocd.ccmall.shop)
                      │  Tunnel (아웃바운드 연결, LB·공인 IP 불필요)
                      ▼
OKE ─ infra/cloudflared ──HTTP──> infra/telos-envoy (Envoy Gateway, ClusterIP, 프록시만)
                                      │ HTTPRoute (hostnames)
                        ┌─────────────┴──────────────┐
                        ▼                            ▼
              telos-dev/web (nginx)         argocd/argocd-server
```

---

## 1. Terraform 과 ArgoCD 의 경계

| 누가 | 무엇을 | 어디 |
| --- | --- | --- |
| Terraform `01-infra` | VCN·서브넷·게이트웨이·보안목록, OKE·노드 풀, OCIR, Cloudflare Tunnel·DNS | `terraform/envs/dev/01-infra` |
| Terraform `02-bootstrap` | ArgoCD 설치, Root Application 1개, 비밀값 Secret(cloudflared 토큰, OCIR pull), OCI Helm repo 등록 | `terraform/envs/dev/02-bootstrap` |
| ArgoCD | 그 외 클러스터 안의 전부: envoy-gateway, Gateway/HTTPRoute, cloudflared, 서비스 앱 | `gitops/` |

원칙 (MoongCheap 과 동일)
- Terraform 은 gitops 파일을 수정하지 않는다. `terraform output` 값을 사람이(또는 CI 가) gitops 에 커밋한다.
- ArgoCD 는 자기 자신을 GitOps 로 관리하지 않는다. ArgoCD 설정 변경은 `gitops/platform/argocd/values.yaml` 수정 후 `02-bootstrap` 에서 `terraform apply`.
- Cloudflare Tunnel 은 `config_src = "local"`: 호스트→서비스 라우팅은 `gitops/platform/cloudflared/configmap.yaml` 이 갖는다.

## 2. 디렉터리

```
.
├── terraform/
│   ├── modules/                 # 기능별 모듈
│   │   ├── network/             #   VCN, IGW, NAT, Service GW, Route Table, Security List, Subnet
│   │   ├── oke/                 #   OKE 클러스터 + 노드 풀(map) + kubeconfig CA
│   │   ├── ocir/                #   컨테이너 레지스트리 (ECR 대체)
│   │   ├── cloudflare/          #   Tunnel + DNS CNAME (MoongCheap 모듈 그대로)
│   │   └── argocd-bootstrap/    #   ArgoCD + Root App + Secret (Terraform→ArgoCD 핸드오프)
│   └── envs/
│       ├── dev/
│       │   ├── 01-infra/        #   클러스터 밖
│       │   ├── 02-bootstrap/    #   클러스터 부트스트랩 (01 의 state 를 읽음)
│       │   ├── deploy.sh
│       │   └── destroy.sh
│       └── prod/README.md       #   나중에 (방식 A/B 설명)
├── gitops/
│   ├── argocd/                  # Root App 이 바라보는 곳 (App of Apps)
│   │   ├── projects/            #   telos-platform, telos-services
│   │   ├── applicationset-platform.yaml      # gitops/platform/**/config.yaml 자동 탐색
│   │   ├── applicationset-services-dev.yaml  # base→env→services→overrides
│   │   ├── application-gateway-resources.yaml
│   │   ├── application-cloudflared.yaml
│   │   └── _prod/               #   Root App 이 제외하는 폴더 (prod 전환 시 밖으로 이동)
│   ├── platform/
│   │   ├── argocd/values.yaml   #   Terraform 이 읽음
│   │   ├── envoy-gateway/       #   config.yaml + values.yaml + resources/(GatewayClass, EnvoyProxy, Gateway, HTTPRoute)
│   │   ├── cloudflared/         #   Deployment + ConfigMap
│   │   └── _optional/           #   external-secrets(OCI Vault), tailscale — 주제 확정 후
│   ├── charts/telos-service/    # MoongCheap moongcheap-service 공통 차트 + files(ConfigMap 마운트) 기능
│   └── values/                  # base / env/{dev,prod} / services/<svc> / overrides/<env>/<svc>
└── ci/github-actions/           # 앱 저장소용 워크플로 템플릿 (빌드→OCIR→gitops PR)
```

## 3. 내일 테스트 순서 (mgmt 서버)

### 3-0. 준비물

| 도구 | 확인 |
| --- | --- |
| Terraform ≥ 1.6 | `terraform version` |
| OCI CLI | `oci --version` (없으면 `bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"`) |
| kubectl, helm | 기존 그대로 |

```bash
# OCI API Key 등록 (콘솔 > 내 프로필 > API keys 에서 키 추가하거나 아래 명령으로 생성)
oci setup config
oci iam region list --output table      # 인증 확인
```

Cloudflare 준비
- API Token 권한: `Account / Cloudflare Tunnel : Edit`, `Zone / DNS : Edit`, `Zone / Zone : Read` (ccmall.shop)
- Account ID, Zone ID: 대시보드 ccmall.shop 개요 오른쪽 사이드바
- `ccmall.shop` apex 에 가비아 시절 A/CNAME 레코드가 있으면 삭제 (또는 tfvars `cloudflare_allow_overwrite = true`)

### 3-1. 인프라 (약 15~25분, OKE 생성이 대부분)

```bash
cd terraform/envs/dev/01-infra
cp terraform.tfvars.example terraform.tfvars   # OCID, Cloudflare 값 입력
terraform init
terraform apply
```

### 3-2. kubectl 컨텍스트 등록

```bash
eval "$(terraform output -raw kubeconfig_command)"
# create-kubeconfig 는 current-context 를 OKE 로 바꾼다. 온프레미스와 헷갈리지 않게 이름 변경
kubectl config rename-context "$(kubectl config current-context)" oci-dev
kubectl --context oci-dev get nodes -o wide
kubectl config use-context kubernetes-admin@kubernetes   # 온프레미스로 돌아갈 때
```

### 3-3. ArgoCD 부트스트랩

```bash
cd ../02-bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

(`terraform/envs/dev/deploy.sh` 가 3-1 ~ 3-3 을 순서대로 실행한다)

### 3-4. 확인

```bash
kubectl --context oci-dev -n argocd get applications
#  root, envoy-gateway, gateway-resources, cloudflared, web-dev  → 모두 Synced/Healthy
kubectl --context oci-dev -n infra get pods,svc
kubectl --context oci-dev -n telos-dev get pods,svc,httproute
curl -I https://ccmall.shop
# ArgoCD: https://argocd.ccmall.shop  (admin / terraform output -raw argocd_admin_password_command 로 확인)
```

### 3-5. 정리

```bash
cd terraform/envs/dev && ./destroy.sh
```
OCI LB 나 Block Volume 을 만드는 리소스(Service type LoadBalancer, PVC)를 추가했다면 destroy 전에 먼저 지울 것.
클러스터가 사라진 뒤에는 그 리소스들이 고아로 남아 VCN 삭제가 막힌다.

## 4. 막힐 때

| 증상 | 확인 |
| --- | --- |
| `Out of host capacity` (A1.Flex) | tfvars 노드 shape 를 `VM.Standard.E5.Flex` 로 |
| 노드 이미지 선택 실패 (`[0]` index 에러) | `terraform console` → `data` 대신 `oci ce node-pool-options get --node-pool-option-id all` 로 이미지 OCID 확인 후 `node_pools.<name>.image_id` 에 직접 지정 |
| `envoy-gateway` App 이 chart 를 못 받음 | `kubectl -n argocd get secret repo-envoyproxy-oci` 존재 확인. ArgoCD 버전에 따라 `url` 을 `registry-1.docker.io/envoyproxy` 로 바꿔야 할 수 있음 (config.yaml 의 repoURL 도 같이) |
| `gateway-resources` 가 OutOfSync/Missing | envoy-gateway CRD 설치 전이면 정상. retry 로 자동 해소. 계속되면 `kubectl get crd | grep gateway` |
| `ccmall.shop` 접속 시 Cloudflare 1033 | cloudflared Pod 가 안 떠 있음 → `kubectl -n infra logs deploy/cloudflared` (토큰 Secret 확인) |
| 404 (`http_status:404`) | cloudflared ConfigMap 의 hostname 과 접속 호스트 불일치 |
| Envoy 가 404 | HTTPRoute hostnames / backendRef Service 이름 확인: `kubectl -n telos-dev describe httproute web` |
| kubectl 이 `oci` 명령을 못 찾음 | mgmt 의 PATH 에 oci CLI 추가 (kubeconfig 가 `oci ce cluster generate-token` 을 호출) |

## 5. 주제 확정 후 할 일

1. 서비스 추가: `applicationset-services-dev.yaml` elements + `values/services/<svc>.yaml` + `values/overrides/dev/<svc>.yaml` + HTTPRoute
2. 이미지: tfvars `ocir_repositories` 에 추가 → `terraform output ocir_repository_urls` 를 `values/services/<svc>.yaml` 의 `image.repository` 에
3. CI: `ci/github-actions/` 템플릿을 앱 저장소에 복사
4. DB: Autonomous DB / OCI PostgreSQL 이면 `terraform/modules/<db>` 추가, 연결 정보는 Secret 으로 (02-bootstrap 또는 ESO)
5. 하이브리드: `gitops/platform/_optional/tailscale/README.md`
6. prod: `terraform/envs/prod/README.md`
