variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "tenancy_ocid" {
  type        = string
  description = "가용 도메인(AD) 조회용"
}

variable "compartment_ocid" {
  type = string
}

variable "vcn_id" {
  type = string
}

variable "api_subnet_id" {
  type = string
}

variable "worker_subnet_id" {
  type = string
}

variable "lb_subnet_ids" {
  type    = list(string)
  default = []
}

variable "kubernetes_version" {
  type        = string
  description = "예: v1.33.1. null 이면 OKE 최신 버전. 확인: oci ce cluster-options get --cluster-option-id all"
  default     = null
}

variable "cluster_type" {
  type        = string
  description = "BASIC_CLUSTER(컨트롤 플레인 무료) 또는 ENHANCED_CLUSTER(Workload Identity, Virtual Node, 애드온 관리)"
  default     = "BASIC_CLUSTER"

  validation {
    condition     = contains(["BASIC_CLUSTER", "ENHANCED_CLUSTER"], var.cluster_type)
    error_message = "cluster_type 은 BASIC_CLUSTER 또는 ENHANCED_CLUSTER 여야 합니다."
  }
}

variable "pods_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.96.0.0/16"
}

variable "ssh_public_key" {
  type        = string
  description = "워커 노드 SSH 공개키 (선택). 노드는 private 서브넷이라 직접 접속하려면 Bastion 이 필요"
  default     = null
}

# Jit-Hub modules/eks 의 node_groups 맵과 같은 방식
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

variable "tags" {
  type    = map(string)
  default = {}
}
