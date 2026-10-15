# OKE (Oracle Kubernetes Engine) 클러스터 + 노드 풀.
#
# AWS(MoongCheap modules/eks, Jit-Hub modules/eks)와의 대응:
#   aws_eks_cluster          -> oci_containerengine_cluster
#   aws_eks_node_group       -> oci_containerengine_node_pool (node_pools 맵으로 여러 개)
#   IRSA                     -> (BASIC 클러스터에는 없음) Workload Identity 는 ENHANCED 클러스터에서만 지원
#   Karpenter                -> 사용하지 않음. 필요하면 OKE Cluster Autoscaler 애드온(ENHANCED)
#   aws eks get-token        -> oci ce cluster generate-token
#
# CNI 는 FLANNEL_OVERLAY 로 둔다. Pod 가 VCN IP 를 소비하지 않아 서브넷 설계가 단순하다.
# (VCN-native(OCI_VCN_IP_NATIVE) 로 바꾸려면 pod 전용 서브넷과 보안 규칙이 추가로 필요)

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

# kubernetes_version 을 지정하지 않으면 현재 OKE 가 지원하는 가장 최신 버전을 쓴다.
data "oci_containerengine_cluster_option" "this" {
  cluster_option_id = "all"
}

locals {
  name = "${var.project}-${var.env}"

  # "v1.33.1" 형식. 문자열 정렬이라 패치 자리수가 다르면 순서가 틀릴 수 있으니 테스트 후엔 고정값을 권장.
  kubernetes_version = coalesce(
    var.kubernetes_version,
    reverse(sort(data.oci_containerengine_cluster_option.this.kubernetes_versions))[0]
  )
  k8s_version_number = trimprefix(local.kubernetes_version, "v")

  ad_names = [for ad in data.oci_identity_availability_domains.this.availability_domains : ad.name]
}

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_ocid
  name               = "${local.name}-oke"
  vcn_id             = var.vcn_id
  kubernetes_version = local.kubernetes_version
  type               = var.cluster_type
  freeform_tags      = var.tags

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = var.api_subnet_id
  }

  options {
    service_lb_subnet_ids = var.lb_subnet_ids

    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }
}

# ─── 노드 이미지 선택 ───────────────────────────────────────────────────────
# OKE 전용 Oracle Linux 이미지 중 (k8s 버전 일치 + 아키텍처 일치 + GPU 아님) 최신 것을 고른다.
# 이미지 이름 예: Oracle-Linux-8.10-2025.06.17-0-OKE-1.33.1-1006
#               Oracle-Linux-8.10-aarch64-2025.06.17-0-OKE-1.33.1-1006

data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = oci_containerengine_cluster.this.id
  compartment_id      = var.compartment_ocid
}

locals {
  node_images = {
    for pool_name, pool in var.node_pools : pool_name => (
      pool.image_id != null ? pool.image_id : reverse(sort([
        for s in data.oci_containerengine_node_pool_option.this.sources :
        "${s.source_name}|${s.image_id}"
        if s.source_type == "IMAGE"
        && strcontains(s.source_name, "OKE-${local.k8s_version_number}")
        && !strcontains(s.source_name, "GPU")
        && strcontains(s.source_name, "Oracle-Linux")
        && (strcontains(pool.shape, ".A1.") || strcontains(pool.shape, ".A2.")) == strcontains(s.source_name, "aarch64")
      ]))[0]
    )
  }
}

resource "oci_containerengine_node_pool" "this" {
  for_each = var.node_pools

  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_ocid
  name               = "${local.name}-${each.key}"
  kubernetes_version = local.kubernetes_version
  node_shape         = each.value.shape
  ssh_public_key     = var.ssh_public_key
  freeform_tags      = var.tags

  node_shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = each.value.image_id != null ? each.value.image_id : split("|", local.node_images[each.key])[1]
    boot_volume_size_in_gbs = each.value.boot_volume_size_in_gbs
  }

  node_config_details {
    size = each.value.size

    # 서울/춘천은 AD 가 1개. AD 가 여러 개인 리전이면 모든 AD 에 분산 배치된다.
    dynamic "placement_configs" {
      for_each = local.ad_names
      content {
        availability_domain = placement_configs.value
        subnet_id           = var.worker_subnet_id
      }
    }

    node_pool_pod_network_option_details {
      cni_type = "FLANNEL_OVERLAY"
    }

    freeform_tags = var.tags
  }

  # MoongCheap 의 nodeSelector(workload: system 등)와 같은 용도
  dynamic "initial_node_labels" {
    for_each = each.value.labels
    content {
      key   = initial_node_labels.key
      value = initial_node_labels.value
    }
  }

  lifecycle {
    # 새 OKE 이미지가 나올 때마다 노드 풀이 교체되지 않도록 한다. 이미지 갱신은 의도적으로만.
    ignore_changes = [node_source_details[0].image_id]
  }
}

# kubeconfig 에서 CA 인증서를 꺼내 02-bootstrap 의 helm/kubernetes provider 에 넘긴다.
data "oci_containerengine_cluster_kube_config" "this" {
  cluster_id    = oci_containerengine_cluster.this.id
  endpoint      = "PUBLIC_ENDPOINT"
  token_version = "2.0.0"
}
