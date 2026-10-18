resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = var.oidc_discovery_url
  oidc_client_id     = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  default_role       = "user"
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

# Any Kanidm person in idm_all_persons. Kanidm's groups_name scope returns
# group names in the `groups` claim.
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

# Only accounts whose `roles` claim contains "admin" (Kanidm grants that to cluster-admins).
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
