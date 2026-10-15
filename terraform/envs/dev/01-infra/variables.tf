variable "project" {
  type    = string
  default = "telos"
}

variable "env" {
  type    = string
  default = "dev"
}

# ─── OCI ────────────────────────────────────────────────────────────────────
variable "oci_profile" {
  type        = string
  description = "~/.oci/config 의 프로필 이름"
  default     = "DEFAULT"
}

variable "region" {
  type        = string
  description = "OCI 리전 (서울 ap-seoul-1, 춘천 ap-chuncheon-1)"
  default     = "ap-seoul-1"
}

variable "region_key" {
  type        = string
  description = "OCIR 호스트용 리전 키 (ap-seoul-1 = icn, ap-chuncheon-1 = yny)"
  default     = "icn"
}

variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type        = string
  description = "개인 계정이면 tenancy_ocid 와 같은 값(root compartment). 대회 제공 환경이면 받은 컴파트먼트"
}

variable "api_allowed_cidrs" {
  type        = list(string)
  description = "Kubernetes API 접근 허용 CIDR. mgmt 서버 공인 IP/32 권장 (curl ifconfig.me)"
  default     = ["0.0.0.0/0"]
}

# 온프레미스 k8s 와 Tailscale 로 묶을 가능성이 있으면 대역이 겹치지 않게 미리 바꿔 둘 것
variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "pods_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.96.0.0/16"
}

variable "kubernetes_version" {
  type        = string
  description = "null 이면 OKE 최신 버전"
  default     = null
}

variable "cluster_type" {
  type    = string
  default = "BASIC_CLUSTER"
}

variable "node_pools" {
  type = map(object({
    shape                   = string
    ocpus                   = number
    memory_in_gbs           = number
    size                    = number
    boot_volume_size_in_gbs = optional(number, 50)
    image_id                = optional(string)
    labels                  = optional(map(string), {})
  }))
}

variable "ssh_public_key" {
  type    = string
  default = null
}

variable "ocir_repositories" {
  type        = list(string)
  description = "만들 OCIR 리포지토리 (주제 확정 후 추가)"
  default     = []
}

# ─── Cloudflare ─────────────────────────────────────────────────────────────
variable "cloudflare_api_token" {
  type        = string
  description = "권한: Account / Cloudflare Tunnel:Edit, Zone / DNS:Edit, Zone / Zone:Read"
  sensitive   = true
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type        = string
  description = "ccmall.shop Zone ID"
}

variable "cloudflare_subdomains" {
  type        = list(string)
  description = "\"@\" = ccmall.shop (nginx 페이지), argocd = argocd.ccmall.shop"
  default     = ["@", "argocd"]
}

variable "cloudflare_allow_overwrite" {
  type    = bool
  default = false
}
