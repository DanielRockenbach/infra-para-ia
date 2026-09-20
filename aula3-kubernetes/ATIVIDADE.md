# Aula 3 — Atividade avaliativa da semana

| | |
|---|---|
| **Entrega** | Em dupla, prazo de 4 dias, um único PDF no ambiente da disciplina. Nota de 0 a 10, sem bônus. Cada evidência vale 2,0. |
| **Missão** | Entregar uma versão modificada do `deployment.yaml` da prática e demonstrar um rollout completo com ela. |

## Modificações obrigatórias no YAML entregue

Partam de [`manifests/deployment.yaml`](manifests/deployment.yaml) e façam quatro mudanças:

1. `replicas: 4`, em vez de 3.
2. Imagem inicial `ghcr.io/rodolfo-s-antunes/sentiment-api:v3`. A prática começou em `v2`.
3. Readiness e liveness com `initialDelaySeconds`, `periodSeconds` e `failureThreshold` **diferentes** dos valores do repositório, cada escolha justificada em um comentário `#` de uma linha.
4. Labels `dupla: NOME` e `turma: 2026-2` no `template` (e no `selector`, se quiserem).

Depois de aplicar, executem um rolling update **no sentido inverso ao da aula**, de `v3` para `v2`, com `kubectl set image`, e coletem as evidências antes da faxina.

O cluster é criado do zero, como nas etapas 1 a 5 do [roteiro](ROTEIRO.md). O `service.yaml` pode ser usado como está.

## Evidências

| # | Evidência | Valor |
|---|---|---|
| E1 | `kubectl get rs` mostrando dois ReplicaSets: o novo com 4/4/4 e o antigo com 0 | 2,0 |
| E2 | `kubectl rollout history deployment/sentiment-api` com pelo menos 2 revisões | 2,0 |
| E3 | `curl /versao` antes do rollout (`v3`) e depois (`v2`), no mesmo IP | 2,0 |
| E4 | `kubectl describe pod` de um pod novo, mostrando as linhas Readiness e Liveness com os valores da dupla | 2,0 |
| E5 | O `deployment.yaml` modificado no PDF (ou link para o fork), com os comentários justificando as probes | 2,0 |

## Regra de consistência

Os valores das probes têm que ser os mesmos na E4 e na E5; o número de réplicas tem que bater entre E1 e E5; o IP tem que ser o mesmo nas duas partes da E3. **Divergência zera a evidência.**

## Faxina obrigatória

Depois das capturas:

```bash
az group delete --name aula3-rg --yes --no-wait
```

## Dicas

- Se mudarem o `selector` para incluir `dupla` e `turma`, as mesmas labels precisam estar no `template`, ou o `apply` é recusado.
- Com 4 réplicas e `maxSurge: 1`, o rolling update chega a 5 pods por instantes. Com requests de 100m cabem no D2as_v7; se aumentarem os requests, confiram `kubectl get pods` por `Pending`.
- Justificativa de probe é uma frase sobre o comportamento da aplicação, não sobre o número: "o modelo carrega em menos de 2 s, então 3 s de carência bastam" vale; "escolhemos 3" não.
- A E4 sai de qualquer pod do ReplicaSet novo: `kubectl describe pod $(kubectl get pods -l app=sentiment-api -o jsonpath='{.items[0].metadata.name}') | grep -E "Readiness|Liveness"`.
