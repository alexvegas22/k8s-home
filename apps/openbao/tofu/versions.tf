terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # The Vault provider talks to OpenBao unchanged (same API surface).
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
