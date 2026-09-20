locals {
  tags = {
    gerenciado_por = "terraform"
    aula           = "4"
    dupla          = var.dupla
    turma          = var.turma
  }
}

# A "pasta" que agrupa tudo, igual à que vocês criaram pelo portal na aula 1.
resource "azurerm_resource_group" "rg" {
  name     = "aula4-rg"
  location = var.location
  tags     = local.tags
}

# Um sufixo aleatório para o endereço da API não colidir com o de outra dupla.
# Ele nasce aqui e só existe no estado: é o exemplo mais simples de por que
# o Terraform precisa lembrar o que criou.
resource "random_string" "sufixo" {
  length  = 4
  upper   = false
  special = false
}

# O az container create da aula 1, em forma de arquivo.
resource "azurerm_container_group" "api" {
  name                = "sentiment-api"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "sentiment-${var.dupla}-${random_string.sufixo.result}"
  restart_policy      = "Always"

  container {
    name   = "api"
    image  = "ghcr.io/rodolfo-s-antunes/sentiment-api:${var.imagem_tag}"
    cpu    = var.cpu
    memory = var.memoria

    ports {
      port     = 8000
      protocol = "TCP"
    }
  }

  tags = local.tags
}
