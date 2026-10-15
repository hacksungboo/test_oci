# OCIR (OCI Container Registry) 리포지토리. MoongCheap modules/ecr 와 같은 역할.
#
# 이미지 주소 형식: <region-key>.ocir.io/<tenancy-namespace>/<repository>:<tag>
#   예) icn.ocir.io/axabcdef1234/telos/web:dev-1a2b3c4
#   region-key: ap-seoul-1 = icn, ap-chuncheon-1 = yny
#
# 로그인(docker / GitHub Actions):
#   docker login <region-key>.ocir.io
#     username: <tenancy-namespace>/<oci 사용자 이름>   (Identity Domain 계정이면 <namespace>/OracleIdentityCloudService/<user> 일 수 있음)
#     password: Auth Token (콘솔 > 내 프로필 > Auth tokens 에서 발급, 비밀번호 아님)

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

resource "oci_artifacts_container_repository" "this" {
  for_each = toset(var.repositories)

  compartment_id = var.compartment_ocid
  display_name   = "${var.project}/${each.value}"
  is_public      = var.is_public
  is_immutable   = false
  freeform_tags  = var.tags
}
