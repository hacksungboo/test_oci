variable "project" {
  type        = string
  description = "프로젝트 이름 (리소스 이름 prefix)"
}

variable "env" {
  type        = string
  description = "환경 구분 (dev/prod)"
}

variable "compartment_ocid" {
  type        = string
  description = "리소스를 만들 컴파트먼트 OCID (개인 계정이면 tenancy OCID = root compartment)"
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "api_subnet_cidr" {
  type        = string
  description = "Kubernetes API Endpoint 서브넷. null 이면 vcn_cidr 의 첫 /28"
  default     = null
}

variable "worker_subnet_cidr" {
  type        = string
  description = "워커 노드 서브넷. null 이면 vcn_cidr 기준 x.x.10.0/24"
  default     = null
}

variable "lb_subnet_cidr" {
  type        = string
  description = "OCI Load Balancer 서브넷 (create_lb_subnet = true 일 때만). null 이면 x.x.20.0/24"
  default     = null
}

variable "create_lb_subnet" {
  type        = bool
  description = "cloudflared 만 쓰면 LB 가 필요 없으므로 기본 false"
  default     = false
}

variable "api_allowed_cidrs" {
  type        = list(string)
  description = "Kubernetes API(6443)에 접근 가능한 외부 CIDR. mgmt 서버 공인 IP/32 로 좁힐 것"
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
