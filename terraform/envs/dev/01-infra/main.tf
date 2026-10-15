# Layer 01 - 클러스터 "밖"의 인프라 (MoongCheap: Terraform 관리 영역)
#   network    : VCN, IGW, NAT, Service Gateway, Route Table, Security List, Subnet
#   oke        : OKE 클러스터 + 노드 풀
#   ocir       : 컨테이너 레지스트리 (ECR 대체)
#   cloudflare : Tunnel + DNS(CNAME). 라우팅 규칙은 gitops 의 cloudflared ConfigMap 이 담당
#
# 클러스터 "안"은 02-bootstrap(ArgoCD 설치 + Root App + Secret) 이후 ArgoCD 가 관리한다.

locals {
  tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

module "network" {
  source = "../../../modules/network"

  project           = var.project
  env               = var.env
  compartment_ocid  = var.compartment_ocid
  vcn_cidr          = var.vcn_cidr
  api_allowed_cidrs = var.api_allowed_cidrs
  tags              = local.tags

  # cloudflared 만 쓰므로 LB 서브넷은 만들지 않는다
  create_lb_subnet = false
}

module "oke" {
  source = "../../../modules/oke"

  project          = var.project
  env              = var.env
  tenancy_ocid     = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid

  vcn_id           = module.network.vcn_id
  api_subnet_id    = module.network.api_subnet_id
  worker_subnet_id = module.network.worker_subnet_id
  lb_subnet_ids    = module.network.lb_subnet_ids

  pods_cidr          = var.pods_cidr
  services_cidr      = var.services_cidr
  kubernetes_version = var.kubernetes_version
  cluster_type       = var.cluster_type
  node_pools         = var.node_pools
  ssh_public_key     = var.ssh_public_key
  tags               = local.tags
}

module "ocir" {
  source = "../../../modules/ocir"

  project          = var.project
  tenancy_ocid     = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  region_key       = var.region_key
  repositories     = var.ocir_repositories
  tags             = local.tags
}

module "cloudflare" {
  source = "../../../modules/cloudflare"

  project         = var.project
  env             = var.env
  account_id      = var.cloudflare_account_id
  zone_id         = var.cloudflare_zone_id
  tunnel_name     = "${var.project}-${var.env}-oke"
  subdomains      = var.cloudflare_subdomains
  allow_overwrite = var.cloudflare_allow_overwrite
}
