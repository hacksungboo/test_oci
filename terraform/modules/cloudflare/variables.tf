variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "account_id" {
  type        = string
  description = "Cloudflare 계정 ID (대시보드 우측 사이드바)"
}

variable "zone_id" {
  type        = string
  description = "ccmall.shop Zone ID (도메인 개요 페이지 우측 사이드바)"
}

variable "tunnel_name" {
  type        = string
  description = "Cloudflare Tunnel 이름. 온프레미스 터널과 겹치지 않게 할 것"
}

# 1단계 서브도메인만 쓴다. 2단계(api.dev.ccmall.shop 등)는 Universal SSL 이 덮지 않는다 (MoongCheap C-12).
variable "subdomains" {
  type        = list(string)
  description = "Tunnel 에 연결할 레코드 이름 목록 (zone 기준 상대 이름, apex 는 \"@\")"
  default     = ["@"]
}

variable "allow_overwrite" {
  type        = bool
  description = "같은 이름의 기존 레코드가 있으면 덮어쓸지 여부"
  default     = false
}
