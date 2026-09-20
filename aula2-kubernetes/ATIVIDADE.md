# Aula 2 — Atividade avaliativa da semana

| | |
|---|---|
| **Entrega** | Em dupla, prazo de 4 dias, um único PDF no ambiente da disciplina. Nota de 0 a 10, sem bônus. Cada evidência vale 2,0. |
| **Missão** | Refazer o exercício em um cluster novo, com o Pod e o Service em um namespace próprio da dupla, a partir de manifestos escritos por vocês. |

## O que entregar

Escrevam um arquivo `dupla.yaml` com **três objetos separados por `---`**:

1. Um **Namespace** chamado `dupla-NOME` (nomes da dupla, minúsculas, sem acento).
2. Um **Pod** da imagem `ghcr.io/rodolfo-s-antunes/sentiment-api:v2` dentro desse namespace, com ao menos as labels `app: sentiment-api`, `dupla: NOME` e `turma: 2026-2`.
3. Um **Service** do tipo `LoadBalancer` no mesmo namespace, cujo `selector` use a label `dupla`, e não apenas `app`.

Lembrem do `-n dupla-NOME` em todo comando `kubectl`, ou vocês vão procurar no namespace `default` um pod que está em outro lugar.

O cluster é criado do zero, como nas etapas 1 a 6 do [roteiro](ROTEIRO.md). Os manifestos da pasta `manifests/` servem de ponto de partida, mas o `dupla.yaml` é de vocês: nenhum dos três objetos existe pronto no repositório.

## Evidências

| # | Evidência | Valor |
|---|---|---|
| E1 | `kubectl get pods -n dupla-NOME -o wide --show-labels` mostrando o pod Running com as três labels | 2,0 |
| E2 | `kubectl get svc -n dupla-NOME` com EXTERNAL-IP atribuído | 2,0 |
| E3 | `curl /prediz` e `curl /hostname` no IP público, com resposta visível | 2,0 |
| E4 | Portal Azure: o cluster AKS dentro de `aula2-rg`, com o nome da assinatura visível | 2,0 |
| E5 | O `dupla.yaml` completo no PDF (ou link para o fork), válido e coerente com E1 a E3 | 2,0 |

## Regra de consistência

O IP da E2 tem que ser o mesmo da E3; o hostname respondido na E3 tem que ser o nome do pod da E1; o namespace tem que ser o mesmo em todas as evidências. **Divergência zera a evidência.**

## Faxina obrigatória

Depois das capturas:

```bash
az group delete --name aula2-rg --yes --no-wait
```

## Dicas

- Um Namespace é o objeto mais curto do Kubernetes: `apiVersion: v1`, `kind: Namespace` e um `metadata.name`. Consulte `kubectl explain namespace`.
- Pod e Service entram no namespace pelo campo `metadata.namespace`. Sem ele, caem no `default` mesmo com o arquivo certo.
- `kubectl apply -f dupla.yaml` aplica os três objetos de uma vez, na ordem em que aparecem: o Namespace precisa vir primeiro.
- Se o `curl` não responder, `kubectl get endpoints -n dupla-NOME` diz se o `selector` encontrou o pod (o Warning sobre Endpoints deprecado é esperado).
