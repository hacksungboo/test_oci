# (선택) 온프레미스 k8s(VMware) <-> OKE 하이브리드 연결

대회 주제 확인 후 결정. Jit-Hub 에서는 Terraform(`modules/tailscale`) + Ansible 로 EKS 노드에 Tailscale 을 올렸다.

OKE 에 적용할 때의 선택지
- Tailscale Kubernetes Operator 를 Helm 으로 설치 (이 폴더에 config.yaml + values.yaml 을 만들고 상위 platform/ 으로 이동)
  - repoURL: https://pkgs.tailscale.com/helmcharts, chart: tailscale-operator
  - OAuth client id/secret 은 02-bootstrap 에서 Secret 으로 주입 (cloudflared 토큰과 같은 방식)
- Subnet router 로 온프레미스 대역(MetalLB, NFS ubuntu1)을 OKE 에 광고
- 온프레미스 ArgoCD(Hub)에 OKE 를 Spoke 로 등록하려면 Jit-Hub 03-platform 의 argocd-manager ServiceAccount + cluster Secret 패턴을 재사용

주의: OKE pods_cidr(10.244.0.0/16), services_cidr(10.96.0.0/16), VCN(10.0.0.0/16)이 온프레미스 대역과 겹치지 않는지 먼저 확인할 것.
온프레미스 kubeadm 기본값도 10.244.0.0/16, 10.96.0.0/12 라 겹칠 가능성이 높다 → 01-infra 에서 pods_cidr/services_cidr 를 바꿔야 할 수 있음.
