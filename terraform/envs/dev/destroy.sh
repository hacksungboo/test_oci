#!/bin/bash
# 역순 삭제. 02 를 먼저 지워 ArgoCD 가 만든 리소스를 정리한 뒤 클러스터를 지운다.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

destroy_layer () {
  local LAYER=$1
  echo ""
  echo "================================="
  echo " Destroying ${LAYER}"
  echo "================================="
  cd "${ROOT_DIR}/${LAYER}"
  terraform init
  terraform destroy -auto-approve
}

# Root App 을 지우면 하위 Application 이 남을 수 있으므로, 클러스터째 지우는 01 에서 같이 정리된다.
destroy_layer "02-bootstrap" || echo "02-bootstrap destroy 실패 - 클러스터 삭제로 진행 (01-infra 가 클러스터째 삭제)"
destroy_layer "01-infra"
