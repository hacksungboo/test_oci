# OKE용 VCN 네트워크.
#
# AWS(MoongCheap modules/vpc + modules/nat)와의 대응:
#   VPC            -> oci_core_vcn
#   IGW            -> oci_core_internet_gateway
#   NAT Instance   -> oci_core_nat_gateway (관리형, 별도 인스턴스 없음)
#   (없음)          -> oci_core_service_gateway  : 노드가 OKE·OCIR·Object Storage 등 OCI 서비스에
#                                                   인터넷을 거치지 않고 접근하는 경로. OKE 필수 구성.
#   Security Group -> oci_core_security_list (서브넷 단위)
#
# 서브넷 구성 (Oracle 공식 예시 "Flannel CNI, Public API Endpoint, Private Worker" 기준):
#   - api   (public)  : Kubernetes API Endpoint. mgmt 서버에서 kubectl/terraform 으로 접근
#   - worker(private) : 워커 노드. 인바운드 없음, 외부로는 NAT 로만 나감
#   - lb    (public)  : 지금은 사용하지 않음. cloudflared 터널이 아웃바운드로만 연결되므로
#                       OCI Load Balancer 가 필요 없다. 나중에 LB 가 필요해지면 create_lb_subnet = true
#
# 참고: https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengnetworkconfigexample.htm

locals {
  name = "${var.project}-${var.env}"

  # "All <region> Services in Oracle Services Network"
  all_services_cidr = data.oci_core_services.all.services[0].cidr_block
  all_services_id   = data.oci_core_services.all.services[0].id

  icmp_path_discovery = { type = 3, code = 4 }

  # 서브넷 대역을 따로 주지 않으면 vcn_cidr(/16 가정)에서 잘라 쓴다
  api_cidr    = coalesce(var.api_subnet_cidr, cidrsubnet(var.vcn_cidr, 12, 0))
  worker_cidr = coalesce(var.worker_subnet_cidr, cidrsubnet(var.vcn_cidr, 8, 10))
  lb_cidr     = coalesce(var.lb_subnet_cidr, cidrsubnet(var.vcn_cidr, 8, 20))
}

data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.name}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = replace(substr("${var.project}${var.env}", 0, 15), "-", "")
  freeform_tags  = var.tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-igw"
  enabled        = true
  freeform_tags  = var.tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-natgw"
  freeform_tags  = var.tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-sgw"
  freeform_tags  = var.tags

  services {
    service_id = local.all_services_id
  }
}

# ─── Route Tables ────────────────────────────────────────────────────────────

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-rt-public"
  freeform_tags  = var.tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-rt-private"
  freeform_tags  = var.tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    destination       = local.all_services_cidr
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }
}

# ─── Security List: Kubernetes API Endpoint ─────────────────────────────────

resource "oci_core_security_list" "api" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-sl-api"
  freeform_tags  = var.tags

  # 외부(mgmt 서버 등) -> API 서버. api_allowed_cidrs 를 내 공인 IP/32 로 좁히는 걸 권장.
  dynamic "ingress_security_rules" {
    for_each = var.api_allowed_cidrs
    content {
      description = "External kubectl access"
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 6443
        max = 6443
      }
    }
  }

  ingress_security_rules {
    description = "Worker to API endpoint"
    protocol    = "6"
    source      = local.worker_cidr
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    description = "Worker to control plane"
    protocol    = "6"
    source      = local.worker_cidr
    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    description = "Path discovery"
    protocol    = "1"
    source      = local.worker_cidr
    icmp_options {
      type = local.icmp_path_discovery.type
      code = local.icmp_path_discovery.code
    }
  }

  egress_security_rules {
    description      = "Control plane to OKE service"
    protocol         = "6"
    destination      = local.all_services_cidr
    destination_type = "SERVICE_CIDR_BLOCK"
  }

  egress_security_rules {
    description      = "Path discovery to OCI services"
    protocol         = "1"
    destination      = local.all_services_cidr
    destination_type = "SERVICE_CIDR_BLOCK"
    icmp_options {
      type = local.icmp_path_discovery.type
      code = local.icmp_path_discovery.code
    }
  }

  egress_security_rules {
    description = "Control plane to worker nodes"
    protocol    = "6"
    destination = local.worker_cidr
  }

  egress_security_rules {
    description = "Path discovery to workers"
    protocol    = "1"
    destination = local.worker_cidr
    icmp_options {
      type = local.icmp_path_discovery.type
      code = local.icmp_path_discovery.code
    }
  }
}

# ─── Security List: Worker Nodes ────────────────────────────────────────────

resource "oci_core_security_list" "worker" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-sl-worker"
  freeform_tags  = var.tags

  ingress_security_rules {
    description = "Pod to pod across worker nodes"
    protocol    = "all"
    source      = local.worker_cidr
  }

  ingress_security_rules {
    description = "Control plane to worker nodes"
    protocol    = "6"
    source      = local.api_cidr
  }

  ingress_security_rules {
    description = "Path discovery"
    protocol    = "1"
    source      = "0.0.0.0/0"
    icmp_options {
      type = local.icmp_path_discovery.type
      code = local.icmp_path_discovery.code
    }
  }

  # LB 서브넷을 켰을 때만 NodePort/kube-proxy 헬스체크 허용
  dynamic "ingress_security_rules" {
    for_each = var.create_lb_subnet ? [1] : []
    content {
      description = "LB to NodePorts"
      protocol    = "6"
      source      = local.lb_cidr
      tcp_options {
        min = 30000
        max = 32767
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.create_lb_subnet ? [1] : []
    content {
      description = "LB to kube-proxy health"
      protocol    = "6"
      source      = local.lb_cidr
      tcp_options {
        min = 10256
        max = 10256
      }
    }
  }

  # 워커 노드 아웃바운드는 전부 허용 (NAT -> 인터넷: 이미지 pull, cloudflared 터널, GitHub 등)
  egress_security_rules {
    description = "All outbound"
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  egress_security_rules {
    description      = "Workers to OCI services"
    protocol         = "6"
    destination      = local.all_services_cidr
    destination_type = "SERVICE_CIDR_BLOCK"
  }
}

# ─── Security List: Load Balancer (선택) ────────────────────────────────────

resource "oci_core_security_list" "lb" {
  count = var.create_lb_subnet ? 1 : 0

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name}-sl-lb"
  freeform_tags  = var.tags

  ingress_security_rules {
    description = "HTTP"
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "HTTPS"
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    description = "LB to workers"
    protocol    = "6"
    destination = local.worker_cidr
  }
}

# ─── Subnets (regional) ─────────────────────────────────────────────────────

resource "oci_core_subnet" "api" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${local.name}-sn-api"
  cidr_block                 = local.api_cidr
  dns_label                  = "api"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.api.id]
  freeform_tags              = var.tags
}

resource "oci_core_subnet" "worker" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${local.name}-sn-worker"
  cidr_block                 = local.worker_cidr
  dns_label                  = "worker"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.worker.id]
  freeform_tags              = var.tags
}

resource "oci_core_subnet" "lb" {
  count = var.create_lb_subnet ? 1 : 0

  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${local.name}-sn-lb"
  cidr_block                 = local.lb_cidr
  dns_label                  = "lb"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.lb[0].id]
  freeform_tags              = var.tags
}
