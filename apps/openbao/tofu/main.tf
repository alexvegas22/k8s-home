resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = var.oidc_discovery_url
  oidc_client_id     = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  # v34l is in Kanidm's cluster-admins group, which maps to the `admin`
  # claim and the admin-policy. Only cluster-admins can authenticate to
  # this client (see apps/openbao/kanidm-oidc-client.yaml).
  default_role = "admin"
  # Kanidm signs id_tokens with ES256 by default; OpenBao defaults to RS256 only.
  jwt_supported_algs = ["ES256", "RS256"]
}

# Admin policy: full access. Narrow before wider rollout.
resource "vault_policy" "admin" {
  name   = "admin-policy"
  policy = <<-POL
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  POL
}

# Non-admin role, kept for explicit login if the OpenBao client's scope map
# is widened beyond cluster-admins later.
resource "vault_jwt_auth_backend_role" "user" {
  backend               = vault_jwt_auth_backend.oidc.path
  role_name             = "user"
  role_type             = "oidc"
  user_claim            = "preferred_username"
  groups_claim          = "groups"
  oidc_scopes           = ["openid", "profile", "email", "groups_name"]
  allowed_redirect_uris = var.ui_redirect_uris
  token_policies        = ["default"]
  token_ttl             = 3600
}

# Only accounts whose `roles` claim contains "admin" (Kanidm grants that to
# cluster-admins). v34l is a member of cluster-admins.
resource "vault_jwt_auth_backend_role" "admin" {
  backend               = vault_jwt_auth_backend.oidc.path
  role_name             = "admin"
  role_type             = "oidc"
  user_claim            = "preferred_username"
  groups_claim          = "groups"
  oidc_scopes           = ["openid", "profile", "email", "groups_name"]
  allowed_redirect_uris = var.ui_redirect_uris
  bound_claims          = { roles = "admin" }
  token_policies        = [vault_policy.admin.name]
  token_ttl             = 3600
}

# Dedicated KV v2 mount for application secrets. Kept separate from any
# pre-existing `secret/` mount so this config can be applied safely.
resource "vault_mount" "openwebui" {
  path        = "openwebui"
  type        = "kv"
  description = "Open WebUI application secrets"
  options     = { version = "2" }
}

resource "vault_kv_secret_v2" "openwebui" {
  mount = vault_mount.openwebui.path
  name  = "config"

  data_json = jsonencode({
    OPENAI_API_KEYS  = var.openwebui_openai_api_keys
    WEBUI_SECRET_KEY = var.openwebui_webui_secret_key
  })
}

# External Secrets Operator authenticates with its own service account and
# reads only the Open WebUI secret.
resource "vault_policy" "openwebui" {
  name = "openwebui-read"

  policy = <<-POL
    path "openwebui/data/config" {
      capabilities = ["read"]
    }

    path "openwebui/metadata/config" {
      capabilities = ["read"]
    }

    path "sys/internal/ui/mounts/openwebui" {
      capabilities = ["read"]
    }
  POL
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# OpenBao uses its own service account token and CA to review tokens. The
# chart's default authDelegator ClusterRoleBinding grants the required access.
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend              = vault_auth_backend.kubernetes.path
  kubernetes_host      = "https://kubernetes.default.svc"
  disable_local_ca_jwt = false
}

resource "vault_kubernetes_auth_backend_role" "openwebui" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "openwebui"
  bound_service_account_names      = ["openwebui-secrets"]
  bound_service_account_namespaces = ["openwebui"]
  token_policies                   = [vault_policy.openwebui.name]
  token_ttl                        = 3600
}

# LiteLLM application secrets.
resource "vault_mount" "litellm" {
  path        = "litellm"
  type        = "kv"
  description = "LiteLLM application secrets"
  options     = { version = "2" }
}

resource "vault_kv_secret_v2" "litellm" {
  mount = vault_mount.litellm.path
  name  = "config"

  data_json = jsonencode({
    LITELLM_MASTER_KEY = var.litellm_master_key
    LITELLM_SALT_KEY   = var.litellm_salt_key
    OPENCODE_API_KEY   = var.litellm_opencode_api_key
    OPENAI_API_KEY     = var.litellm_openai_api_key
    UI_USERNAME        = var.litellm_ui_username
    UI_PASSWORD        = var.litellm_ui_password
  })
}

resource "vault_policy" "litellm" {
  name = "litellm-read"

  policy = <<-POL
    path "litellm/data/config" {
      capabilities = ["read"]
    }

    path "litellm/metadata/config" {
      capabilities = ["read"]
    }

    path "sys/internal/ui/mounts/litellm" {
      capabilities = ["read"]
    }
  POL
}

resource "vault_kubernetes_auth_backend_role" "litellm" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "litellm"
  bound_service_account_names      = ["litellm-secrets"]
  bound_service_account_namespaces = ["litellm"]
  token_policies                   = [vault_policy.litellm.name]
  token_ttl                        = 3600
}
