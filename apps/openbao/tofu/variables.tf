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

variable "openwebui_openai_api_keys" {
  description = "Semicolon-separated OpenCode API keys, one per openaiBaseApiUrls entry. Pass via TF_VAR_openwebui_openai_api_keys."
  type        = string
  sensitive   = true
}

variable "openwebui_webui_secret_key" {
  description = "Open WebUI session secret. Pass via TF_VAR_openwebui_webui_secret_key."
  type        = string
  sensitive   = true
}

variable "litellm_master_key" {
  description = "LiteLLM proxy master key. Pass via TF_VAR_litellm_master_key."
  type        = string
  sensitive   = true
}

variable "litellm_salt_key" {
  description = "LiteLLM key-encryption salt. Keep stable. Pass via TF_VAR_litellm_salt_key."
  type        = string
  sensitive   = true
}

variable "litellm_opencode_api_key" {
  description = "OpenCode Zen API key for LiteLLM. Pass via TF_VAR_litellm_opencode_api_key."
  type        = string
  sensitive   = true
}

variable "litellm_openai_api_key" {
  description = "OpenAI API key for LiteLLM. Pass via TF_VAR_litellm_openai_api_key."
  type        = string
  sensitive   = true
}

variable "litellm_ui_username" {
  description = "LiteLLM UI username."
  type        = string
  default     = "admin"
}

variable "litellm_ui_password" {
  description = "LiteLLM UI password. Pass via TF_VAR_litellm_ui_password."
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
