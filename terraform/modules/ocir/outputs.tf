output "namespace" {
  description = "Tenancy Object Storage namespace (OCIR 경로·로그인 사용자명에 들어감)"
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "registry_host" {
  value = "${var.region_key}.ocir.io"
}

output "repository_urls" {
  description = "gitops/values/services/<service>.yaml 의 image.repository 에 넣을 값"
  value = {
    for name in var.repositories :
    name => "${var.region_key}.ocir.io/${data.oci_objectstorage_namespace.this.namespace}/${var.project}/${name}"
  }
}
