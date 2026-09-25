variable "node_vm_size" {
  description = "Tamanho da VM dos nós do AKS"
  type        = string
  default     = "Standard_D2as_v7"
}

variable "node_count" {
  description = "Número de nós do node pool padrão"
  type        = number
  default     = 1
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aula4-aks-${var.dupla}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "aula4-${var.dupla}"
  sku_tier            = "Free"

  default_node_pool {
  name       = "default"
  node_count = var.node_count
  vm_size    = var.node_vm_size
  zones      = []
}

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}
# retry apply
