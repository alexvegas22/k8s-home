variable "openbao_address" {
  description = "OpenBao API address."
  type        = string
  default     = "https://openbao.m15ty.com"
}

variable "oidc_discovery_url" {
  description = "Kanidm OIDC issuer for the openbao client."
  type        = string
  default     = "https://auth.m15ty.com/oauth2/openid/openbao"
}

variable "oidc_client_id" {
  description = "Kanidm OAuth2 client id (CLIENT_ID from secret openbao/openbao-kanidm-oauth2-credentials)."
  type        = string
  default     = "openbao"
}

variable "oidc_client_secret" {
  description = "Kanidm OAuth2 client secret (CLIENT_SECRET from the same secret). Pass via TF_VAR_oidc_client_secret."
  type        = string
  sensitive   = true
}

variable "ui_redirect_uris" {
  description = "Allowed redirect URIs for the UI and CLI login flows."
  type        = list(string)
  default = [
    "https://openbao.m15ty.com/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]
}
