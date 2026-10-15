variable "argocd_chart_version" {
  type        = string
  description = "argo/argo-cd chart 버전. 확인: helm repo add argo https://argoproj.github.io/argo-helm && helm search repo argo/argo-cd"
  default     = "10.10.5"
}

variable "argocd_apps_chart_version" {
  type    = string
  default = "2.0.6"
}

variable "argocd_hostname" {
  type    = string
  default = "argocd.ccmall.shop"
}

variable "gitops_repo_url" {
  type    = string
  default = "https://github.com/hacksungboo/test_oci.git"
}

variable "gitops_revision" {
  type        = string
  description = "MoongCheap 은 develop/main 브랜치로 환경을 나눴다. 1차 테스트는 main 하나로 시작"
  default     = "main"
}

variable "gitops_repo_token" {
  type        = string
  description = "저장소가 private 일 때만 GitHub PAT (Contents: Read)"
  default     = ""
  sensitive   = true
}

# ─── (선택) OCIR pull Secret ────────────────────────────────────────────────
variable "app_namespaces" {
  type    = list(string)
  default = ["telos-dev"]
}

variable "ocir_username" {
  type        = string
  description = "<tenancy-namespace>/<user>"
  default     = ""
}

variable "ocir_auth_token" {
  type      = string
  default   = ""
  sensitive = true
}
