output "cluster_id" {
  value = oci_containerengine_cluster.this.id
}

output "cluster_name" {
  value = oci_containerengine_cluster.this.name
}

output "kubernetes_version" {
  value = local.kubernetes_version
}

output "cluster_endpoint" {
  description = "https://<public-ip>:6443"
  value       = "https://${oci_containerengine_cluster.this.endpoints[0].public_endpoint}"
}

output "cluster_ca_certificate" {
  description = "base64 인코딩된 CA (kubeconfig 의 certificate-authority-data)"
  value       = yamldecode(data.oci_containerengine_cluster_kube_config.this.content)["clusters"][0]["cluster"]["certificate-authority-data"]
}

output "node_pool_ids" {
  value = { for k, v in oci_containerengine_node_pool.this : k => v.id }
}

output "node_images" {
  description = "노드 풀별로 선택된 이미지 (이름|OCID)"
  value       = local.node_images
}
