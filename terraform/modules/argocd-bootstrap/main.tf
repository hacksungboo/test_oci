# Terraform 과 ArgoCD 의 경계(handoff) 지점.
#
# 이 모듈이 클러스터 안에 만드는 것은 "ArgoCD 가 스스로 만들 수 없는 것" 뿐이다.
#   1) ArgoCD 자체 (helm_release)                       - MoongCheap: "ArgoCD 는 자기 자신을 GitOps 로 관리하지 않는다"
#   2) Root Application 1개 (argocd-apps chart)         - gitops/argocd/ 를 바라보는 App of Apps. 여기서부터 ArgoCD 담당
#   3) 비밀값 Secret                                    - cloudflared 토큰, (선택) OCIR pull, (선택) private repo 자격증명
#   4) OCI Helm 레지스트리 등록(docker.io/envoyproxy)   - envoy-gateway chart 를 ArgoCD 가 받기 위한 repository Secret
#
# 그 외 클러스터 안의 모든 것(envoy-gateway, cloudflared, 앱, HTTPRoute ...)은 gitops/ 에서 ArgoCD 가 관리한다.
# MoongCheap 은 비밀값을 Secrets Manager + ESO 로 넣었는데, OCI 에서 같은 구조(OCI Vault + ESO)를 쓰려면
# Vault·Dynamic Group·정책이 추가로 필요해서 1차 테스트에서는 Terraform 이 Secret 을 직접 넣는다.
# (전환 방법은 gitops/platform/_optional/external-secrets/README.md)

# ─── 1) infra 네임스페이스 + cloudflared 토큰 ───────────────────────────────
# infra 네임스페이스 안의 Deployment/ConfigMap 은 ArgoCD 가 만들고, Secret 만 여기서 넣는다.
resource "kubernetes_namespace" "infra" {
  metadata {
    name = var.infra_namespace
  }
}

resource "kubernetes_secret" "cloudflared_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }

  data = {
    token = var.cloudflare_tunnel_token
  }
}

# ─── 2) ArgoCD ──────────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # gitops/platform/argocd/values.yaml (공통) + 환경별 override
  values = [
    var.argocd_values,
    yamlencode({
      global = {
        domain = var.argocd_hostname
      }
    })
  ]

  wait    = true
  timeout = 900
}

# ─── 3) ArgoCD repository Secret ────────────────────────────────────────────
# envoy-gateway Helm chart 는 OCI 레지스트리(docker.io/envoyproxy/gateway-helm)에 있다.
# ArgoCD 가 OCI Helm 저장소에서 chart 를 받으려면 enableOCI 가 켜진 repository 등록이 필요하다.
resource "kubernetes_secret" "repo_envoy_oci" {
  metadata {
    name      = "repo-envoyproxy-oci"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    name      = "envoyproxy"
    type      = "helm"
    url       = "docker.io/envoyproxy"
    enableOCI = "true"
  }

  depends_on = [helm_release.argocd]
}

# gitops 저장소가 private 일 때만 생성
resource "kubernetes_secret" "repo_gitops" {
  count = var.gitops_repo_token == "" ? 0 : 1

  metadata {
    name      = "repo-gitops"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.gitops_repo_url
    username = var.gitops_repo_username
    password = var.gitops_repo_token
  }

  depends_on = [helm_release.argocd]
}

# ─── 4) (선택) OCIR imagePullSecret ─────────────────────────────────────────
# OCIR 리포지토리를 private 로 두면 앱 네임스페이스마다 pull Secret 이 필요하다.
# 값이 비어 있으면 아무것도 만들지 않는다 (nginx 테스트 페이지는 Docker Hub 이미지라 불필요).
locals {
  create_ocir_pull = var.ocir_auth_token != ""
}

resource "kubernetes_namespace" "app" {
  for_each = local.create_ocir_pull ? toset(var.app_namespaces) : toset([])

  metadata {
    name = each.value
  }
}

resource "kubernetes_secret" "ocir_pull" {
  for_each = kubernetes_namespace.app

  metadata {
    name      = "ocir-pull"
    namespace = each.value.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.ocir_registry_host) = {
          username = var.ocir_username
          password = var.ocir_auth_token
          auth     = base64encode("${var.ocir_username}:${var.ocir_auth_token}")
        }
      }
    })
  }
}

# ─── 5) Root Application (App of Apps) ──────────────────────────────────────
# 이 Application 하나만 Terraform 이 만들고, 나머지 AppProject/ApplicationSet/Application 은
# 전부 gitops/argocd/ 디렉터리에서 ArgoCD 가 읽어 만든다.
resource "helm_release" "root_app" {
  name      = "argocd-root"
  namespace = var.argocd_namespace

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [yamlencode({
    applications = {
      (var.root_app_name) = {
        namespace = var.argocd_namespace
        project   = "default"
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_revision
          path           = var.gitops_root_path
          directory = {
            recurse = true
            # 아직 적용하지 않을 prod 리소스는 gitops/argocd/_prod/ 에 둔다 (prod 전환 시 밖으로 옮김)
            exclude = "_prod/*"
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.argocd_namespace
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          retry = {
            limit = 10
            backoff = {
              duration    = "10s"
              factor      = 2
              maxDuration = "3m"
            }
          }
        }
      }
    }
  })]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.repo_envoy_oci,
    kubernetes_secret.repo_gitops,
    kubernetes_secret.cloudflared_token,
  ]
}
