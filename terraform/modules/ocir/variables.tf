variable "project" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "region_key" {
  type        = string
  description = "OCIR 호스트용 리전 키 (ap-seoul-1 = icn, ap-chuncheon-1 = yny)"
}

variable "repositories" {
  type        = list(string)
  description = "만들 리포지토리 이름 목록. 실제 이름은 <project>/<name>"
  default     = []
}

variable "is_public" {
  type        = bool
  description = "true 면 imagePullSecret 없이 pull 가능. 해커톤 편의용, 운영에서는 false 권장"
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
