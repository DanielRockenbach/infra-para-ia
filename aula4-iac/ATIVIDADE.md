# Aula 4 — Atividade avaliativa da semana

| | |
|---|---|
| **Entrega** | Em dupla, prazo de 4 dias, um único PDF no ambiente da disciplina. Nota de 0 a 10. Cada evidência vale 2,0. |
| **Missão** | Responder à pergunta com que a Aula 3 terminou: o cluster inteiro como um arquivo, revisado no Git e provisionado por pull request. |

Na Aula 3 o cluster nasceu de um `az aks create` digitado no terminal, e some junto com a memória de quem digitou. Nesta atividade ele nasce de um arquivo Terraform que passa por revisão antes de existir.

## O que entregar

No seu fork, um arquivo novo `aula4-iac/aks.tf` que crie um cluster AKS equivalente ao das Aulas 2 e 3, dentro do mesmo `aula4-rg` da prática. Quatro exigências:

1. **O cluster**, com um nó `Standard_D2as_v7` e o control plane no tier `Free`, como nas Aulas 2 e 3.
2. **Duas variáveis novas** em `variables.tf`, `node_vm_size` e `node_count`, com `default`, usadas pelo cluster.
3. **Um output** com o nome do cluster.
4. **As tags `dupla` e `turma`** em todos os recursos, reaproveitando o `local.tags` que já existe no `main.tf`.

O cluster tem que ser provisionado **por pull request**, com o job `apply` rodando depois do merge, e destruído pelo workflow `terraform-aula4-destroy` depois que as capturas estiverem prontas.

## Evidências

| # | Evidência | Valor |
|---|---|---|
| E1 | O plano no log do job `plan` do pull request, ou a aba Summary, mostrando `1 to add` e o recurso `azurerm_kubernetes_cluster` | 2,0 |
| E2 | O job `apply` verde na aba Actions do seu fork, com o output do nome do cluster visível | 2,0 |
| E3 | `az aks get-credentials` seguido de `kubectl get nodes`, com o nó em `Ready` | 2,0 |
| E4 | O workflow `terraform-aula4-destroy` verde e o portal sem `aula4-rg` e sem o grupo `MC_` | 2,0 |
| E5 | Link do pull request mergeado no seu fork, mostrando o `aks.tf` com as tags exigidas | 2,0 |

## Regra de consistência

O nome do cluster tem que ser o mesmo na E1, na E2 e na E3, e o usuário do GitHub tem que ser o da dupla na E1 e na E5. **Divergência zera a evidência.**

## Faxina obrigatória

Depois das capturas, as duas camadas, nesta ordem:

```
Actions → terraform-aula4-destroy → Run workflow → confirmacao: destruir
```

```bash
./bootstrap-limpeza.sh
az group list -o table
```

E apague o secret `AZURE_CREDENTIALS` do fork.

## Bônus conceitual, sem nota

Gerem o `aks.tf` com um assistente de IA e relatem em três linhas o que o `terraform validate` ou o `plan` obrigaram a corrigir. É a parte mais útil do exercício e não vale ponto nenhum de propósito.

## Dicas

- Os argumentos mínimos de `azurerm_kubernetes_cluster` são `name`, `location`, `resource_group_name`, `dns_prefix`, `sku_tier = "Free"`, o bloco `default_node_pool` com `name` (até 12 caracteres minúsculos), `node_count` e `vm_size`, o bloco `identity { type = "SystemAssigned" }` e `tags`. Não é preciso `linux_profile` nem chave SSH.
- **As variáveis novas precisam de `default`.** O workflow roda o Terraform com `-input=false`, então uma variável sem valor não abre um prompt: ela derruba o job. Se preferirem passar os valores pelo `terraform.tfvars` em vez do `default`, lembrem de comitar o arquivo no mesmo pull request.
- O `plan` do pull request tem que dizer `1 to add`, e não `4 to add`. Se vier 4, o estado do robô está vazio, sinal de que a prática foi destruída e não refeita. Refaçam a Etapa 8 antes de abrir o pull request da atividade.
- O AKS cria sozinho um segundo resource group, `MC_aula4-rg_<nome-do-cluster>_eastus`, com o nó, o disco e a rede. O `destroy` remove os dois, e a E4 exige o portal sem nenhum deles.
- Para a E3: `az aks get-credentials -g aula4-rg -n <nome-do-cluster> --overwrite-existing` e depois `kubectl get nodes`.
- Se o plano ou o apply falhar com `VM size ... is not allowed`, rodem o [`check_region.sh`](../check_region.sh) da raiz do repositório para ver os tamanhos liberados na assinatura de vocês, e ajustem o `default` de `node_vm_size`.
- O AKS leva de 5 a 10 minutos no apply e de 3 a 6 no destroy. O runner do GitHub tem tempo de sobra, mas não cancelem o job achando que travou.
- Custo de cerca de US$ 0,10 por hora com o cluster de pé. Destruam logo depois das capturas.
- **Não criem um output com credenciais.** O `kube_config` do AKS é um atributo sensível: ele apareceria no log do job e na aba Summary, que são públicos no seu fork. A E3 sai do `az aks get-credentials`, que busca a credencial na hora, sem guardar nada no repositório.
