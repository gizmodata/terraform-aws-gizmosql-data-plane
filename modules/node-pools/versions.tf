terraform {
  required_version = ">= 1.3"

  required_providers {
    # `values` is a list on both the 2.x and 3.x providers, so either works.
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17"
    }
  }
}
