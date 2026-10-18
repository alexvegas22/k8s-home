# Auth: export BAO_TOKEN (root or a token with equivalent policy) before running.
# Never commit the token.
provider "vault" {
  address = var.openbao_address
}
