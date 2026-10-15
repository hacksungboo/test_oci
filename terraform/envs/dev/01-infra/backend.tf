# 1차 테스트는 local state (Jit-Hub 방식).
# terraform.tfstate 에는 cloudflared 토큰 등 비밀값이 들어가므로 절대 커밋하지 말 것 (.gitignore 처리됨).
#
# 팀 공유가 필요해지면 OCI Object Storage 의 S3 호환 API 로 옮긴다 (MoongCheap 의 S3 backend 와 같은 역할).
#   1) Object Storage 버킷 생성 (예: telos-tfstate), 콘솔 > 내 프로필 > Customer secret keys 발급
#   2) 아래 블록 주석 해제 후 terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket                      = "telos-tfstate"
#     key                         = "dev/01-infra/terraform.tfstate"
#     region                      = "ap-seoul-1"
#     endpoints                   = { s3 = "https://<namespace>.compat.objectstorage.ap-seoul-1.oraclecloud.com" }
#     skip_region_validation      = true
#     skip_credentials_validation = true
#     skip_requesting_account_id  = true
#     skip_metadata_api_check     = true
#     skip_s3_checksum            = true
#     use_path_style              = true
#   }
# }
