# Aula 4 — Infraestrutura como Código

A mesma API das aulas anteriores, que na Aula 1 você criou clicando no portal e digitando `az container create`, agora nasce de um arquivo. Você escreve o estado desejado em Terraform, roda `plan` para ver o que vai acontecer e `apply` para acontecer. Na primeira metade da prática isso roda na sua mão, no Cloud Shell. Na segunda metade quem roda é o GitHub Actions, a partir de um pull request, que é como equipes de verdade mexem em infraestrutura.

| Arquivo | O que é |
|---|---|
| `ROTEIRO.md` | **Comece por aqui:** o passo a passo da prática no Azure e no GitHub |
| `ATIVIDADE.md` | A atividade avaliativa da semana |
| `versions.tf` | As versões: do Terraform, do provider do Azure e do provider random |
| `main.tf` | Os recursos: o resource group, o sufixo aleatório e o container da API |
| `variables.tf` | O que varia de dupla para dupla, com as regras de validação |
| `terraform.tfvars` | Os valores desta dupla. **Edite antes do primeiro plan** |
| `outputs.tf` | O que sai no fim: a URL da API, o IP e o nome do resource group |
| `bootstrap.sh` | Cria o que fica fora do Terraform: a storage account do estado e a identidade do robô |
| `bootstrap-limpeza.sh` | Desfaz o bootstrap |

## Começar

Edite `terraform.tfvars` primeiro, trocando `SUADUPLA` pelo apelido da dupla. O valor que vem no repositório é inválido de propósito, e o `plan` recusa enquanto ele estiver lá.

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
terraform plan
```

## A imagem

A aula 4 não constrói imagem nova. O Terraform aponta para `ghcr.io/rodolfo-s-antunes/sentiment-api` nas tags `v2` e `v3`, as mesmas das Aulas 2 e 3, construídas por [`.github/workflows/build-aula2.yml`](../.github/workflows/build-aula2.yml). A prática começa em `v2` e troca para `v3` para mostrar o que o Terraform faz quando um atributo não pode ser alterado no lugar.

## Custo e faxina

A prática inteira custa cerca de US$ 0,06, porque a Azure Container Instance sobe em um ou dois minutos e fica de pé por pouco tempo.

A faxina aqui tem duas camadas, e as duas são obrigatórias:

1. O workflow `terraform-aula4-destroy` apaga o que o Terraform criou, ou seja, o resource group `aula4-rg`.
2. O `./bootstrap-limpeza.sh` apaga o que o Terraform não criou, ou seja, a storage account do estado e o service principal do robô.

A ordem importa. Se você apagar o estado antes de destruir a infraestrutura, o Terraform perde a memória do que criou e sobra recurso ligado consumindo crédito.
