variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "infra_namespace" {
  type        = string
  description = "envoy-gateway, cloudflared 가 올라가는 네임스페이스 (MoongCheap 과 동일하게 infra)"
  default     = "infra"
}

variable "argocd_chart_version" {
  type        = string
  description = "argo/argo-cd chart 버전. 확인: helm search repo argo/argo-cd --versions | head"
}

variable "argocd_apps_chart_version" {
  type        = string
  description = "argo/argocd-apps chart 버전 (2.x 부터 applications 가 map 형식)"
}

variable "argocd_values" {
  type        = string
  description = "gitops/platform/argocd/values.yaml 내용"
}

variable "argocd_hostname" {
  type        = string
  description = "ArgoCD UI 도메인 (예: argocd.ccmall.shop)"
}

variable "cloudflare_tunnel_token" {
  type      = string
  sensitive = true
}

variable "gitops_repo_url" {
  type = string
}

variable "gitops_revision" {
  type    = string
  default = "main"
}

variable "gitops_root_path" {
  type        = string
  description = "Root Application 이 바라볼 경로"
  default     = "gitops/argocd"
}

variable "root_app_name" {
  type    = string
  default = "root"
}

variable "gitops_repo_username" {
  type    = string
  default = "git"
}

variable "gitops_repo_token" {
  type        = string
  description = "gitops 저장소가 private 일 때만 GitHub PAT(read 권한) 입력. public 이면 빈 값"
  default     = ""
  sensitive   = true
}

variable "app_namespaces" {
  type        = list(string)
  description = "OCIR pull Secret 을 넣을 앱 네임스페이스"
  default     = []
}

variable "ocir_registry_host" {
  type    = string
  default = ""
}

variable "ocir_username" {
  type        = string
  description = "<tenancy-namespace>/<user>"
  default     = ""
}

variable "ocir_auth_token" {
  type        = string
  description = "OCI Auth Token. 비어 있으면 OCIR pull Secret 을 만들지 않는다"
  default     = ""
  sensitive   = true
}
