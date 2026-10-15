# OCI 인증은 mgmt 서버의 ~/.oci/config (API Key) 를 사용한다.
#   oci setup config  또는 콘솔 > 내 프로필 > API keys > Add API key 로 생성
provider "oci" {
  region              = var.region
  config_file_profile = var.oci_profile
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
