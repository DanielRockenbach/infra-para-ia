variable "dupla" {
  description = "Apelido da dupla, só letras minúsculas e dígitos, de 3 a 12 caracteres. Vai para as tags e para o endereço da API."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.dupla))
    error_message = "Use só letras minúsculas e dígitos, de 3 a 12 caracteres, sem espaço nem hífen. Edite terraform.tfvars."
  }
}

variable "turma" {
  description = "Identificação da turma, usada nas tags."
  type        = string
  default     = "2026-2"
}

variable "location" {
  description = "Região do Azure. eastus é a região padrão da disciplina."
  type        = string
  default     = "eastus"
}

variable "imagem_tag" {
  description = "Tag da imagem ghcr.io/rodolfo-s-antunes/sentiment-api a executar."
  type        = string
  default     = "v2"

  validation {
    condition     = contains(["v1", "v2", "v3"], var.imagem_tag)
    error_message = "imagem_tag deve ser v1, v2 ou v3."
  }
}

variable "cpu" {
  description = "vCPUs do container."
  type        = number
  default     = 1
}

variable "memoria" {
  description = "Memória do container, em GB."
  type        = number
  default     = 1
}
