# MoongCheap modules/cloudflare 와 동일한 원칙.
#
# Tunnel 의 실제 라우팅 규칙(어떤 호스트를 클러스터 내부 어떤 Service 로 보낼지)은 여기서 관리하지 않는다.
# config_src = "local" 로 두면 그 설정은 cloudflared 를 실행하는 쪽(ArgoCD 가 배포하는
# gitops/platform/cloudflared/configmap.yaml)이 직접 담당한다.
# 이 모듈은 Tunnel 자체의 생성과, 도메인을 그 Tunnel 로 연결하는 DNS 레코드만 다룬다.
#
# MoongCheap 과 다른 점: 토큰을 AWS Secrets Manager 에 넣지 않고 output 으로만 내보낸다.
# 02-bootstrap 레이어가 그 값을 K8s Secret(infra/cloudflared-token)으로 주입한다.

data "cloudflare_zone" "this" {
  zone_id = var.zone_id
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.account_id
  name       = var.tunnel_name
  secret     = random_id.tunnel_secret.b64_std
  config_src = "local"
}

# subdomains 의 "@" 는 apex(ccmall.shop) 를 뜻한다.
# 주의: apex 에 가비아 시절 A 레코드 등이 남아 있으면 CNAME 생성이 실패한다.
#       Cloudflare 대시보드 DNS 탭에서 기존 @ 레코드를 먼저 지우거나 allow_overwrite = true 로 둘 것.
resource "cloudflare_record" "this" {
  for_each = toset(var.subdomains)

  zone_id         = var.zone_id
  name            = each.value
  type            = "CNAME"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  proxied         = true
  allow_overwrite = var.allow_overwrite
  comment         = "Managed by Terraform (${var.project}-${var.env} tunnel)"
}
