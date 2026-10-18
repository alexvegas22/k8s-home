# OpenBao configuration (OpenTofu)

Manages the OpenBao OIDC login (Kanidm) and its roles/policies, mirroring the
manual setup. Only config lives in git; the state contains secrets and stays local
(gitignored).

## Use

```bash
cd apps/openbao/tofu
export BAO_TOKEN="$(kubectl get secret -n openbao openbao-init-keys -o jsonpath='{.data.init\.json}' | base64 -d | python3 -c 'import json,sys;print(json.load(sys.stdin)["root_token"])')"
export TF_VAR_oidc_client_secret="$(kubectl get secret -n openbao openbao-kanidm-oauth2-credentials -o jsonpath='{.data.CLIENT_SECRET}' | base64 -d)"
tofu init
tofu plan
tofu apply
```

## Notes
- Provider is `hashicorp/vault` (OpenBao is API-compatible).
- Local state holds the client secret and tokens; keep it out of git.
- Not yet adopted into ArgoCD; this is run by hand.
