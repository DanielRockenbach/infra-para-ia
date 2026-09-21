terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Nenhum backend declarado de propósito.
  # No Cloud Shell o estado é local, e no GitHub Actions o workflow
  # grava um backend_ci.tf com o backend azurerm antes do init.
}

provider "azurerm" {
  features {}

  # A assinatura vem da variável de ambiente ARM_SUBSCRIPTION_ID, que o
  # provider da linha 4.x exige. Veja a etapa 1 do ROTEIRO.
  # Em vez de registrar todos os providers de recurso do Azure (dezenas,
  # e lento), registramos só os que a aula usa. Se a sua assinatura já os
  # tiver, nada acontece.
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.ContainerInstance",
    "Microsoft.Storage",
    "Microsoft.ContainerService",
  ]
}
