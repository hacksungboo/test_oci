output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_token" {
  description = "cloudflared 실행용 토큰"
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.tunnel_token
  sensitive   = true
}

output "cname_target" {
  value = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
}

output "fqdns" {
  description = "Tunnel 에 연결된 호스트 목록. gitops/platform/cloudflared/configmap.yaml 과 HTTPRoute hostnames 에 같은 값을 쓴다"
  value = [
    for s in var.subdomains :
    s == "@" ? data.cloudflare_zone.this.name : "${s}.${data.cloudflare_zone.this.name}"
  ]
}
