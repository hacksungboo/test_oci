# ── 02-bootstrap 이 terraform_remote_state 로 읽는 값 ─────────────────────────
output "region" {
  value = var.region
}

output "oci_profile" {
  value = var.oci_profile
}

output "cluster_id" {
  value = module.oke.cluster_id
}

output "cluster_name" {
  value = module.oke.cluster_name
}

output "kubernetes_version" {
  value = module.oke.kubernetes_version
}

output "cluster_endpoint" {
  value = module.oke.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = module.oke.cluster_ca_certificate
}

# 비밀값. `terraform output -raw cloudflare_tunnel_token` 으로만 꺼낸다. 커밋·메신저 공유 금지.
output "cloudflare_tunnel_token" {
  value     = module.cloudflare.tunnel_token
  sensitive = true
}

# ── 사람이 쓰는 값 (gitops/ 의 자리표시자를 채울 때) ──────────────────────────
output "kubeconfig_command" {
  description = "mgmt 서버에서 kubectl 컨텍스트 등록"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT --profile ${var.oci_profile}"
}

output "fqdns" {
  description = "gitops/platform/cloudflared/configmap.yaml, HTTPRoute hostnames 와 일치해야 한다"
  value       = module.cloudflare.fqdns
}

output "tunnel_id" {
  value = module.cloudflare.tunnel_id
}

output "ocir_namespace" {
  value = module.ocir.namespace
}

output "ocir_registry_host" {
  value = module.ocir.registry_host
}

output "ocir_repository_urls" {
  description = "gitops/values/services/<service>.yaml 의 image.repository"
  value       = module.ocir.repository_urls
}

output "node_images" {
  value = module.oke.node_images
}
