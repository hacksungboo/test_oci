#!/bin/bash
# Jit-Hub envs/*/deploy.sh 와 같은 레이어 순차 적용
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

apply_layer () {
  local LAYER=$1
  echo ""
  echo "================================="
  echo " Applying ${LAYER}"
  echo "================================="
  cd "${ROOT_DIR}/${LAYER}"
  terraform init -upgrade
  terraform plan -out=tfplan
  terraform apply tfplan
}

apply_layer "01-infra"

# kubectl 컨텍스트 등록 (mgmt 서버)
cd "${ROOT_DIR}/01-infra"
eval "$(terraform output -raw kubeconfig_command)"
kubectl get nodes -o wide

apply_layer "02-bootstrap"

echo ""
echo "================================="
echo " Done. ArgoCD 동기화 확인:"
echo "   kubectl -n argocd get applications -w"
echo "================================="
