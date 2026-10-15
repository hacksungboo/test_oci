# (선택) External Secrets Operator + OCI Vault

MoongCheap 은 `AWS Secrets Manager -> ESO -> K8s Secret` 으로 cloudflared 토큰 등을 넣었다.
OCI 에서 같은 구조를 쓰려면 아래가 추가로 필요해서, 1차 테스트에서는 Terraform 이 Secret 을 직접 만든다.

| AWS (MoongCheap) | OCI |
| --- | --- |
| Secrets Manager | OCI Vault (Vault + Master Key + Secret) |
| IRSA (eso Role) | ENHANCED_CLUSTER 의 Workload Identity, 또는 Instance Principal(Dynamic Group + Policy) |
| `ClusterSecretStore.provider.aws` | `ClusterSecretStore.provider.oracle` |

## 전환 순서

1. Terraform: `modules/vault` 추가 (oci_kms_vault, oci_kms_key, oci_vault_secret) → cloudflared 토큰을 Vault Secret 으로 저장
2. Terraform: Dynamic Group(워커 노드) + Policy `Allow dynamic-group <dg> to read secret-family in compartment <c>`
3. 이 폴더의 `config.yaml.example` → `config.yaml` 로 이름 변경 후 `gitops/platform/external-secrets/` 로 이동 (그래야 applicationset-platform 이 집어감)
4. `resources/` 에 ClusterSecretStore(oracle, principalType: InstancePrincipal) + ExternalSecret(cloudflared-token) 작성
5. 02-bootstrap 의 `kubernetes_secret.cloudflared_token` 제거
