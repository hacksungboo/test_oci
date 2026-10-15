output "argocd_url" {
  value = "https://${var.argocd_hostname}"
}

output "argocd_admin_password_command" {
  value = module.argocd_bootstrap.argocd_admin_password_command
}

output "next_steps" {
  value = <<-EOT
    kubectl -n argocd get applications              # root -> envoy-gateway, gateway-resources, cloudflared, web-dev
    kubectl -n infra get pods,svc                   # telos-envoy, cloudflared
    kubectl -n telos-dev get pods,svc,httproute
    curl -I https://ccmall.shop
  EOT
}
