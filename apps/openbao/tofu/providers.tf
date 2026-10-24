# Auth: export VAULT_TOKEN (root or a token with equivalent policy) before
# running. The Vault provider does not read OpenBao's BAO_TOKEN variable.
# Never commit the token.
provider "vault" {
  address = var.openbao_address
}
