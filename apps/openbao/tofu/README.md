# OpenBao configuration (OpenTofu)

Manages the OpenBao OIDC login (Kanidm) and its roles/policies, mirroring the
manual setup. Only config lives in git; the state contains secrets and stays local
(gitignored).

## Use

```bash
cd apps/openbao/tofu
# The hashicorp/vault provider reads VAULT_TOKEN, not BAO_TOKEN.
export VAULT_TOKEN="$(kubectl get secret -n openbao openbao-init-keys -o jsonpath='{.data.init\.json}' | base64 -d | python3 -c 'import json,sys;print(json.load(sys.stdin)["root_token"])')"
export TF_VAR_oidc_client_secret="$(kubectl get secret -n openbao openbao-kanidm-oauth2-credentials -o jsonpath='{.data.CLIENT_SECRET}' | base64 -d)"

# Open WebUI secrets (read from the existing secret once, or set directly).
export TF_VAR_openwebui_openai_api_keys="$(kubectl -n openwebui get secret credentials -o jsonpath='{.data.OPENAI_API_KEYS}' | base64 -d)"
export TF_VAR_openwebui_webui_secret_key="$(kubectl -n openwebui get secret credentials -o jsonpath='{.data.WEBUI_SECRET_KEY}' | base64 -d)"

# LiteLLM secrets. Use a real OpenAI key for TF_VAR_litellm_openai_api_key.
# The OpenCode key is the first entry from the Open WebUI key list.
export TF_VAR_litellm_master_key="sk-$(openssl rand -hex 24)"
export TF_VAR_litellm_salt_key="$(openssl rand -hex 32)"
export TF_VAR_litellm_opencode_api_key="$(kubectl -n openwebui get secret credentials -o jsonpath='{.data.OPENAI_API_KEYS}' | base64 -d | cut -d';' -f1)"
export TF_VAR_litellm_openai_api_key='<openai-api-key>'
export TF_VAR_litellm_ui_password="$(openssl rand -hex 16)"

tofu init
tofu plan
tofu apply
```

If there is no existing `credentials` secret yet, generate the values instead:

```bash
export TF_VAR_openwebui_openai_api_keys='opencode-key-1;opencode-key-2'
export TF_VAR_openwebui_webui_secret_key="$(openssl rand -hex 32)"
```

## Existing OpenBao installations

If the OIDC auth method or roles were created manually before this config was
adopted, import them once before applying:

```bash
tofu import vault_jwt_auth_backend.oidc oidc
tofu import vault_jwt_auth_backend_role.user auth/oidc/role/user
tofu import vault_jwt_auth_backend_role.admin auth/oidc/role/admin
```

If a role does not exist yet, skip its import; `tofu apply` will create it.
After importing, `tofu plan` should show only the intended changes (for
example, `default_role` moving from `user` to `admin`).

## LiteLLM

This config also creates:

- KV v2 mount `litellm`, secret `config`
- policy `litellm-read`
- Kubernetes auth role `litellm`, bound to service account
  `litellm/litellm-secrets`

External Secrets Operator syncs `litellm/config` into the
`litellm/litellm-credentials` Kubernetes Secret for the LiteLLM proxy.

## Admin access

The OIDC backend's default role is `admin`. Members of Kanidm's
`cluster-admins` group (currently `v34l`) match the `roles=admin` bound claim
and receive `admin-policy`. The OpenBao OAuth2 client is restricted to
`cluster-admins`, so non-admin users cannot authenticate to OpenBao.

## Open WebUI

This config creates:

- KV v2 mount `openwebui`, secret `config`
- policy `openwebui-read`
- Kubernetes auth role `openwebui`, bound to service account
  `openwebui/openwebui-secrets`

External Secrets Operator syncs `openwebui/config` into the
`openwebui/credentials` Kubernetes Secret, which Open WebUI consumes.

## Notes
- Provider is `hashicorp/vault` (OpenBao is API-compatible).
- Local state holds the client secret and tokens; keep it out of git.
- Not yet adopted into ArgoCD; this is run by hand.
