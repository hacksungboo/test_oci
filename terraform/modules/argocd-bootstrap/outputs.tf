output "argocd_namespace" {
  value = var.argocd_namespace
}

output "argocd_release_status" {
  value = helm_release.argocd.status
}

output "root_app_name" {
  value = var.root_app_name
}

output "argocd_admin_password_command" {
  value = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}
