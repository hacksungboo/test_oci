# CI (GitHub Actions) — 주제 확정 후 연결

MoongCheap 의 Jenkins 흐름을 GitHub Actions 로 옮긴 형태. 이 템플릿은 **앱 저장소**에 넣어 쓴다
(Jit-Hub 처럼 앱 저장소와 인프라/GitOps 저장소를 분리). 이 저장소에서는 실행되지 않도록 `.github/workflows/` 밖에 둔다.

```
앱 저장소 push (develop / main)
  -> GitHub Actions: 변경된 서비스만 빌드 (dorny/paths-filter, Jit-Hub 방식)
  -> OCIR push  <region-key>.ocir.io/<namespace>/telos/<service>:<env>-<sha7>
  -> 이 저장소(gitops) 의 gitops/values/overrides/<env>/<service>.yaml 의 image.tag 를 yq 로 수정
  -> PR 생성 (MoongCheap 과 동일: 직접 push 하지 않음)
  -> PR merge -> ArgoCD 자동 Sync
```

## AWS -> OCI 에서 바뀌는 것

| 항목 | MoongCheap / Jit-Hub | OCI |
| --- | --- | --- |
| 레지스트리 | ECR / Harbor | OCIR (`terraform output ocir_repository_urls`) |
| 레지스트리 인증 | IRSA(kaniko) / Harbor robot | `docker login` + OCI Auth Token (GitHub Secret) |
| 노드 이미지 pull | 노드 IAM Role | private repo 면 `ocir-pull` imagePullSecret (02-bootstrap 이 생성) |
| 이미지 아키텍처 | amd64 | A1(ARM) 노드면 `linux/arm64` 도 빌드 |

## 필요한 GitHub Secrets (앱 저장소)

| 이름 | 값 |
| --- | --- |
| `OCIR_REGISTRY` | `icn.ocir.io` |
| `OCIR_NAMESPACE` | `terraform output -raw ocir_namespace` |
| `OCIR_USERNAME` | `<namespace>/<oci-user>` |
| `OCIR_AUTH_TOKEN` | OCI 콘솔 > 내 프로필 > Auth tokens |
| `GITOPS_TOKEN` | 이 저장소에 PR 을 만들 수 있는 GitHub PAT (contents + pull-requests write) |
