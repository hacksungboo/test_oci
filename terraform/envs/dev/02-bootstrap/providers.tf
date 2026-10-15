# Jit-Hub 03-platform 과 같은 방식:
#   클러스터를 만든 레이어(01-infra)의 state 를 읽어 helm/kubernetes provider 를 구성한다.
#   같은 레이어에서 클러스터 생성 + provider 구성을 하면 첫 apply 때 provider 가 엔드포인트를 몰라 실패하므로 분리한다.
#
# 인증은 `aws eks get-token` 대신 `oci ce cluster generate-token` (mgmt 서버에 OCI CLI 필요).

data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "../01-infra/terraform.tfstate"
  }
}

locals {
  cluster_endpoint = data.terraform_remote_state.infra.outputs.cluster_endpoint
  cluster_ca       = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
  token_args = [
    "ce", "cluster", "generate-token",
    "--cluster-id", data.terraform_remote_state.infra.outputs.cluster_id,
    "--region", data.terraform_remote_state.infra.outputs.region,
    "--profile", data.terraform_remote_state.infra.outputs.oci_profile,
  ]
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "oci"
    args        = local.token_args
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_ca

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "oci"
      args        = local.token_args
    }
  }
}
