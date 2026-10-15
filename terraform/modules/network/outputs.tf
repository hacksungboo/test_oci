output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "vcn_cidr" {
  value = var.vcn_cidr
}

output "api_subnet_id" {
  value = oci_core_subnet.api.id
}

output "worker_subnet_id" {
  value = oci_core_subnet.worker.id
}

output "lb_subnet_ids" {
  description = "LB 서브넷을 만들지 않았으면 빈 리스트"
  value       = oci_core_subnet.lb[*].id
}
