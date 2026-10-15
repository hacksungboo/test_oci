# Layer 02 - Terraform -> ArgoCD 핸드오프
#   ArgoCD 설치, Root Application, 비밀값 Secret 까지만 Terraform 이 만든다.
#   이후 클러스터 안의 모든 리소스는 gitops/ 를 ArgoCD 가 동기화한다.

module "argocd_bootstrap" {
  source = "../../../modules/argocd-bootstrap"

  argocd_chart_version      = var.argocd_chart_version
  argocd_apps_chart_version = var.argocd_apps_chart_version

  # ArgoCD 공통 values 는 gitops/ 에 두고(사람이 찾기 쉽게) Terraform 이 읽어서 쓴다
  argocd_values   = file("${path.module}/../../../../gitops/platform/argocd/values.yaml")
  argocd_hostname = var.argocd_hostname

  cloudflare_tunnel_token = data.terraform_remote_state.infra.outputs.cloudflare_tunnel_token

  gitops_repo_url   = var.gitops_repo_url
  gitops_revision   = var.gitops_revision
  gitops_repo_token = var.gitops_repo_token

  app_namespaces     = var.app_namespaces
  ocir_registry_host = data.terraform_remote_state.infra.outputs.ocir_registry_host
  ocir_username      = var.ocir_username
  ocir_auth_token    = var.ocir_auth_token
}
