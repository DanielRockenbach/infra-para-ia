# Aula 3 — Roteiro da prática: Kubernetes II no AKS

Na Aula 2 você colocou um pod no ar e viu que, ao apagá-lo, ninguém o trouxe de volta. Hoje entram os objetos que cuidam dos pods por você: três réplicas mantidas vivas sozinhas, um Service dividindo o tráfego entre elas, e uma troca de versão sem derrubar a API, com direito a voltar atrás. Cada etapa indica onde acontece (**portal**, **terminal** ou **navegador**), o comando exato e o que observar na resposta.

| | |
|---|---|
| **Tempo** | 2h em aula, em dupla. As etapas 1 a 4 são as mesmas da Aula 2 e o conteúdo novo começa na Etapa 5. Refazendo em casa: cerca de 50 minutos. |
| **Pré-requisitos** | Conta gratuita do Azure ativa e a prática da Aula 2 feita: o cluster daquela aula foi apagado na faxina, então hoje criamos um novo. |
| **Custo** | Cerca de US$ 0,35. |

**Como ler as etapas:** PORTAL acontece clicando em [portal.azure.com](https://portal.azure.com). TERMINAL acontece no Cloud Shell (Bash), dentro do próprio portal. NAVEGADOR acontece em uma aba nova, no IP público da API.

## Mapa da prática

| # | Etapa | # | Etapa |
|---|---|---|---|
| 1 | Resource group `aula3-rg` | 7 | Service e load balancing |
| 2 | Cloud Shell | 8 | Readiness e escala |
| 3 | Clonar o repositório | 9 | Rolling update v2 → v3 |
| 4 | Criar o cluster e ler o YAML | 10 | Rollback |
| 5 | Aplicar o Deployment | 11 | Faxina e custo |
| 6 | Ver a auto-recuperação | A | [Atividade da semana](ATIVIDADE.md) |

Da 1 à 4 é a preparação já conhecida da Aula 2; o conteúdo novo começa na 5.

### Onde o crédito é consumido

```
Assinatura
├── Resource group aula3-rg                      ← criado por você
│   └── Cluster AKS aks-aula3                    control plane no tier Free: sem custo
└── Resource group MC_aula3-rg_aks-aula3_eastus  ← criado pelo AKS, sozinho
    ├── VM do nó · Standard_D2as_v7 · ~US$ 0,10/h
    ├── Load Balancer + IP público
    └── Disco e rede virtual do nó
```

---

## Parte 1 — Preparar o ambiente

Quatro etapas idênticas às da Aula 2, trocando `aula2` por `aula3` em todos os nomes. Se algo travar aqui, a tabela de [erros comuns](#erros-comuns) cobre os casos conhecidos.

### Etapa 1 — Criar o resource group `aula3-rg` · PORTAL

Busque **Resource groups** no topo do portal → **+ Create** → nome `aula3-rg`, região **(US) East US** → **Review + create** → **Create**. O grupo da Aula 2 foi apagado na faxina; este é novo e some do mesmo jeito no fim de hoje.

Pela linha de comando é mais rápido, e é uma pista do que vem na Aula 4:

```bash
az group create --name aula3-rg --location eastus
```

### Etapa 2 — Abrir o Cloud Shell · PORTAL + TERMINAL

Ícone **`>_`** na barra do topo → **Bash**. Os providers já foram registrados na Aula 2 e o registro vale para a assinatura inteira, para sempre: hoje basta conferir.

```bash
az account show --output table
az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv
```

A resposta esperada é `Registered`. Se vier `NotRegistered`, rode `az provider register --namespace Microsoft.ContainerService` e siga adiante enquanto ele processa.

### Etapa 3 — Clonar o repositório · TERMINAL

```bash
git clone https://github.com/rodolfo-s-antunes/infra-para-ia.git
cd infra-para-ia/aula3-kubernetes
ls manifests/
```

Saída esperada:

```
deployment.yaml   service.yaml
```

Se o Cloud Shell tiver storage, a pasta da Aula 2 ainda está aí: nesse caso o `git clone` reclama que o diretório existe. Basta `cd infra-para-ia && git pull` e seguir. O `service.yaml` é o mesmo arquivo da aula passada, sem uma vírgula de diferença.

---

## Parte 2 — Criar o cluster

### Etapa 4 — Criar o cluster AKS · TERMINAL

```bash
az aks create \
  --resource-group aula3-rg \
  --name aks-aula3 \
  --location eastus \
  --node-count 1 \
  --node-vm-size Standard_D2as_v7 \
  --tier free \
  --generate-ssh-keys
```

As flags são as mesmas da Aula 2: um nó Standard_D2as_v7 (2 vCPU, 8 GB) com o control plane no tier Free. Hoje esse único nó vai abrigar três réplicas da API, e é por isso que o manifesto declara `requests` pequenos.

> **Enquanto o cluster sobe.** Não fique olhando o terminal: use os 5 a 10 minutos para ler o manifesto de hoje, que é bem maior que o da aula passada. **Não edite nada agora:** a versão inicial é `v2` de propósito.
>
> ```bash
> cat manifests/deployment.yaml
> ```
>
> Procure quatro coisas, nesta ordem: 1) `replicas: 3`; 2) o `selector.matchLabels` e as `labels` do `template`, que precisam ser iguais; 3) o bloco `template`, que é o pod da Aula 2 embutido aqui dentro; 4) as duas probes e a `strategy`. O [Anexo B](#anexo-b--o-deploymentyaml-linha-a-linha) explica o arquivo linha a linha.
>
> Perguntas para a dupla: quantos objetos este arquivo cria, contando os que o cluster cria por conta própria? Onde está o pod da aula passada dentro deste YAML? O que `maxUnavailable: 0` promete? Por que a liveness tem prazos maiores que a readiness?
>
> Se a sessão cair, a criação continua no Azure: reconecte e confira com `az aks show -g aula3-rg -n aks-aula3 --query provisioningState -o tsv`.

---

## Parte 3 — Réplicas que se cuidam sozinhas

### Etapa 5 — Conectar e aplicar o Deployment · TERMINAL

```bash
az aks get-credentials --resource-group aula3-rg --name aks-aula3
kubectl get nodes
kubectl apply -f manifests/deployment.yaml
kubectl rollout status deployment/sentiment-api
kubectl get deploy,rs,pods -o wide
```

Saída esperada (resumida):

```
deployment "sentiment-api" successfully rolled out
NAME                            READY   UP-TO-DATE   AVAILABLE
deployment.apps/sentiment-api   3/3     3            3

NAME                                       DESIRED   CURRENT   READY
replicaset.apps/sentiment-api-6c9f7d8b45   3         3         3

NAME                                  READY   STATUS    RESTARTS   IP
pod/sentiment-api-6c9f7d8b45-2xk7q    1/1     Running   0          10.244.0.x
pod/sentiment-api-6c9f7d8b45-8vqzl    1/1     Running   0          10.244.0.y
pod/sentiment-api-6c9f7d8b45-tn4rp    1/1     Running   0          10.244.0.z
```

Você aplicou um objeto e apareceram cinco. Repare na anatomia dos nomes: `sentiment-api` é o Deployment que você escreveu, `-6c9f7d8b45` identifica o ReplicaSet (um hash do template do pod) e o último pedaço é sorteado para cada pod. Guarde esse hash: quando a versão mudar, na Etapa 9, ele muda junto.

> **Por quê.** Ninguém cria ReplicaSet na mão. Você declara um Deployment; ele cria e versiona ReplicaSets; cada ReplicaSet mantém o número certo de pods. Três objetos, três responsabilidades: histórico e estratégia de atualização, contagem de réplicas, e execução de um container.

```
Deployment sentiment-api     →   ReplicaSet …-6c9f7d8b45      →   pod …-2xk7q
histórico de revisões            "quero 3 pods com esta            pod …-8vqzl
estratégia de update              label e este molde"              pod …-tn4rp
```

O loop de reconciliação roda no ReplicaSet: ele conta pods com a label, compara com `replicas: 3` e cria ou apaga a diferença. Para sempre.

### Etapa 6 — Ver a auto-recuperação acontecer · TERMINAL

```bash
POD=$(kubectl get pods -l app=sentiment-api -o jsonpath='{.items[0].metadata.name}')
echo $POD
kubectl delete pod $POD
kubectl get pods
kubectl describe rs -l app=sentiment-api | grep -A5 Events
```

Saída esperada (resumida):

```
sentiment-api-6c9f7d8b45-8vqzl    1/1     Running             0     6m
sentiment-api-6c9f7d8b45-tn4rp    1/1     Running             0     6m
sentiment-api-6c9f7d8b45-w2m9d    0/1     ContainerCreating   0     3s
# Events do ReplicaSet:
SuccessfulCreate   Created pod: sentiment-api-6c9f7d8b45-w2m9d
```

Em segundos existe um pod novo, com nome novo, no lugar do que você apagou. Compare com a Etapa 10 da Aula 2, quando o pod simplesmente desapareceu e o Service ficou órfão: a diferença é que agora existe alguém encarregado de manter a conta em três. Vale rodar `kubectl get pods -w` em paralelo para assistir à transição `Terminating` → `ContainerCreating` → `Running` ao vivo.

**Cronometrem:** quantos segundos levou? Esse número é o tempo de recuperação da sua aplicação, e depende do tamanho da imagem.

### Etapa 7 — Service e load balancing · TERMINAL

```bash
kubectl apply -f manifests/service.yaml
kubectl get svc sentiment-api -w      # até EXTERNAL-IP sair de <pending>
IP=$(kubectl get svc sentiment-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
for i in $(seq 1 6); do curl -s http://$IP/hostname; echo; done
kubectl get endpoints sentiment-api   # como na Aula 2, ignore o Warning de deprecação do Endpoints
```

Saída esperada (resumida):

```
{"hostname":"sentiment-api-6c9f7d8b45-8vqzl"}
{"hostname":"sentiment-api-6c9f7d8b45-tn4rp"}
{"hostname":"sentiment-api-6c9f7d8b45-8vqzl"}
{"hostname":"sentiment-api-6c9f7d8b45-w2m9d"}
...
ENDPOINTS   10.244.0.x:8000,10.244.0.y:8000,10.244.0.z:8000
```

É a mesma URL, e as respostas vêm de pods diferentes: essa é a prova visual do balanceamento. A distribuição é um round-robin aproximado, então não espere a sequência perfeita 1-2-3-1-2-3; espere ver os três nomes aparecendo ao longo de seis chamadas. O `/hostname` existe na API só para isso.

```
curl / navegador          Service sentiment-api             pod …-2xk7q :8000
http://20.xx.xxx.xxx  →   selector: app=sentiment-api   →   pod …-8vqzl :8000
porta 80                  port 80 → targetPort 8000         pod …-tn4rp :8000
                          endpoints: 3 IPs prontos
```

O mesmo `service.yaml` da Aula 2, sem alteração nenhuma: o selector agora casa com três pods em vez de um, e o Service passa a ser um balanceador. A lista de endpoints é viva: pod que morre sai dela, pod que fica pronto entra.

### Etapa 8 — Readiness e escala · TERMINAL

```bash
kubectl describe pod -l app=sentiment-api | grep -E "Readiness|Liveness"
kubectl scale deployment/sentiment-api --replicas=5
kubectl get pods -w                   # Ctrl+C quando os 5 estiverem 1/1
kubectl get endpoints sentiment-api
kubectl scale deployment/sentiment-api --replicas=3
```

Saída esperada (resumida):

```
Readiness:  http-get http://:8000/health delay=5s period=5s #failure=3
Liveness:   http-get http://:8000/health delay=15s period=10s #failure=3
# no -w, cada pod novo passa por:
0/1  ContainerCreating → 0/1  Running → 1/1  Running
# e a lista de endpoints cresce de 3 para 5 conforme cada um fica 1/1
```

> **Por quê.** A coluna READY mostra `0/1` por alguns segundos mesmo com o pod já em `Running`: o container subiu, mas ainda não respondeu 200 em `/health`. Enquanto isso o Service não manda tráfego para ele. É esse detalhe que evita o erro clássico de servir requisições para um modelo que ainda está carregando, e é ele que faz o rolling update da Etapa 9 acontecer sem nenhuma falha. A liveness é outra coisa: se `/health` parar de responder três vezes seguidas, o container é reiniciado, não apenas tirado do tráfego.

**Volte para três réplicas antes de seguir.** Com um nó D2as_v7 e requests de 100m de CPU por pod, cinco réplicas cabem, mas o rolling update da próxima etapa precisa de folga para criar um pod extra.

*Experimento opcional:* escale para `--replicas=30`. Alguns pods ficam em `Pending`: o `describe` dirá `Insufficient cpu`. Escalar pods não cria máquina. Volte para 3 depois.

O `scale` é um atalho imperativo: o arquivo continua dizendo 3. Em produção, a mudança iria no YAML.

---

## Parte 4 — Trocar a versão sem parar

### Etapa 9 — Rolling update v2 → v3 · TERMINAL

Esta etapa fica melhor a quatro mãos. Uma pessoa da dupla abre uma **segunda aba do Cloud Shell** e deixa a API sob fogo contínuo:

```bash
# aba 1 — deixe rodando durante todo o rollout:
IP=$(kubectl get svc sentiment-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while true; do curl -s http://$IP/versao; echo; sleep 0.5; done
```

A outra pessoa dispara a troca de imagem e acompanha:

```bash
# aba 2:
curl -s http://$IP/versao
kubectl set image deployment/sentiment-api api=ghcr.io/rodolfo-s-antunes/sentiment-api:v3
kubectl rollout status deployment/sentiment-api
kubectl get rs
kubectl rollout history deployment/sentiment-api
```

Saída esperada (resumida):

```
# aba 1, durante o rollout: nenhuma requisição falha
{"versao":"v2"} … {"versao":"v3"} {"versao":"v2"} … {"versao":"v3"}

# aba 2:
NAME                       DESIRED   CURRENT   READY
sentiment-api-6c9f7d8b45   0         0         0        <- ReplicaSet antigo (v2)
sentiment-api-79b4c5f6d2   3         3         3        <- ReplicaSet novo (v3)

REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

Durante a transição as duas versões coexistem por alguns segundos, e a aba 1 mostra respostas alternando entre v2 e v3, sem nenhum erro no meio. O ReplicaSet antigo não é apagado: fica ali, zerado, guardando o molde da versão anterior. É exatamente por isso que o rollback da próxima etapa é instantâneo.

O rolling update em quatro quadros:

| 1 · Início | 2 · maxSurge | 3 · Troca | 4 · Fim |
|---|---|---|---|
| 3 pods v2 no ar, atendendo tudo. | Nasce 1 pod v3. Ele só entra no tráfego quando a readiness passar. | Um pod v2 sai, outro v3 entra. Repete até acabar a fila. | 3 pods v3. O ReplicaSet v2 continua existindo, com 0 réplicas. |

Com `maxSurge: 1` e `maxUnavailable: 0`, nunca há menos de 3 pods prontos. Nenhuma janela de manutenção, nenhuma requisição perdida.

### Etapa 10 — Rollback · TERMINAL

```bash
kubectl rollout undo deployment/sentiment-api
kubectl rollout status deployment/sentiment-api
curl -s http://$IP/versao          # v2 de novo
kubectl get rs
kubectl rollout history deployment/sentiment-api
```

O ReplicaSet antigo volta a subir para três réplicas e o novo cai para zero: os dois trocam de papel. Repare que o histórico ganhou a revisão 3, e não voltou para a 1: no Kubernetes, desfazer também é um fato registrado. Deixe a aba 1 rodando aqui também: o caminho de volta é tão suave quanto o de ida, o que muda a natureza de um deploy quebrado em produção.

Pergunta para a dupla: se a v3 nunca ficasse pronta (readiness falhando), o que o `rollout status` mostraria, e quantas réplicas v2 continuariam atendendo?

**Confira no portal:** abra o cluster → **Kubernetes resources** → **Workloads**. Na aba **Deployments** está o `sentiment-api` com 3/3 prontos; na aba **Replica sets** aparecem os dois conjuntos, um com 3 e outro com 0. É a mesma informação do `kubectl get rs`, em forma de tabela clicável.

---

## Parte 5 — Custo e faxina

### Etapa 11 — Apagar tudo · TERMINAL + PORTAL

**Não saia da aula sem fazer esta etapa.** Colete antes as capturas que a [atividade da semana](ATIVIDADE.md) pede: depois do delete não há como recuperar o histórico de rollout nem o IP público.

```bash
az group delete --name aula3-rg --yes --no-wait
```

Confira depois de 5 a 15 minutos (o `MC_...` sai primeiro; o `aula3-rg` pode levar mais de 10 minutos) que sumiram os dois grupos: `aula3-rg` e o `MC_aula3-rg_aks-aula3_eastus`. Em **Cost Management** → **Cost analysis** o consumo aparece com atraso de algumas horas até um dia; o esperado hoje é algo em torno de US$ 0,35, um pouco mais que a Aula 2, porque o cluster ficou de pé por mais tempo.

Se você quiser pausar em vez de destruir (para continuar em casa no mesmo dia), `az aks stop -g aula3-rg -n aks-aula3` desliga o nó e para a maior parte do custo, mas o IP público continua reservado.

Esta foi a última prática com cluster criado à mão: na Aula 4, criar e apagar tudo isso vira um arquivo.

### Checklist final da prática

- [ ] Resource group `aula3-rg` criado em East US
- [ ] Providers conferidos como Registered
- [ ] Repositório clonado ou atualizado
- [ ] Cluster `aks-aula3` em Succeeded
- [ ] `deployment.yaml` lido durante a espera
- [ ] Deployment aplicado: 3/3 pods Running
- [ ] Pod apagado e substituído sozinho
- [ ] `/hostname` devolveu nomes diferentes
- [ ] Escala para 5 e volta para 3 observada
- [ ] Rolling update v2 → v3 sem falhas no `curl`
- [ ] Dois ReplicaSets visíveis, um zerado
- [ ] Rollback executado e `/versao` de volta em v2
- [ ] Capturas da atividade coletadas
- [ ] Os dois resource groups sumiram da lista

---

## Erros comuns

Ordem de investigação, sempre: `get` para ver o estado, `describe` para ler os eventos, `logs` só depois.

| Sintoma | O que rodar | Causa provável e saída |
|---|---|---|
| Pods em `Pending` depois do `scale` | `kubectl describe pod NOME` | `Insufficient cpu`: requests × réplicas passou do que o nó tem. Reduza as réplicas ou os requests. |
| Pod fica READY `0/1` para sempre | `kubectl describe pod NOME \| grep -A3 Readiness` | `Readiness probe failed`: caminho ou porta errados na probe. Confira `path: /health` e `port: 8000`. |
| Coluna RESTARTS crescendo | `kubectl logs NOME --previous` | Liveness falhando e reiniciando o container. Os logs da encarnação anterior dizem por quê. |
| `rollout status` não termina | `kubectl get pods` / `kubectl rollout undo deployment/sentiment-api` | Imagem inexistente (`ImagePullBackOff`) ou readiness falhando na versão nova. O `undo` resolve na hora. |
| O Deployment não cria pod nenhum | `kubectl describe deploy sentiment-api` | `selector` diferente das labels do `template`. O YAML é recusado na hora do `apply`: as duas listas precisam bater. |
| `/hostname` devolve sempre o mesmo pod | `kubectl get endpoints sentiment-api` | Só um IP na lista: os outros pods não estão prontos (READY 0/1) ou não têm a label do selector. |
| EXTERNAL-IP `<pending>` por mais de 3 min | `kubectl describe svc sentiment-api` | Cota de IP público ou provisionamento lento. Alternativa: `kubectl port-forward svc/sentiment-api 8080:80`. |
| `az aks create` falha com `VM size ... is not allowed in your subscription` | leia a lista de tamanhos no próprio erro; `az vm list-usage --location eastus -o table` mostra as cotas | A conta gratuita só libera alguns tamanhos por região. Escolha um `standard_d2..._v7` da lista, por exemplo `Standard_D2as_v7` ou `Standard_D2s_v7`. Se persistir, avise o professor. |
| A variável `$IP` sumiu | `IP=$(kubectl get svc sentiment-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')` | Cada aba do Cloud Shell tem suas próprias variáveis, e elas se perdem ao reconectar. Redefina na aba nova. |

---

## Anexo A — Comandos de referência

### Deployments e rollouts

| Comando | Para quê |
|---|---|
| `kubectl apply -f deployment.yaml` | Declarar o estado desejado. Reaplicar o mesmo arquivo não muda nada. |
| `kubectl get deploy,rs,pods -o wide` | As três camadas de uma vez: quem manda, quem conta e quem roda. |
| `kubectl scale deployment/NOME --replicas=N` | Mudar o número de réplicas na hora, sem editar o YAML. |
| `kubectl set image deployment/NOME CONTAINER=IMAGEM` | Trocar a versão da imagem e disparar um rolling update. |
| `kubectl rollout status deployment/NOME` | Bloquear o terminal até o rollout terminar (ou travar). |
| `kubectl rollout history deployment/NOME` | A lista de revisões. Com `--revision=N`, o detalhe de uma delas. |
| `kubectl rollout undo deployment/NOME` | Voltar para a revisão anterior. Com `--to-revision=N`, para outra. |
| `kubectl rollout restart deployment/NOME` | Recriar todos os pods sem mudar nada no manifesto. |
| `kubectl get endpoints NOME` | Quem o Service enxerga como pronto neste instante. |
| `kubectl logs -l app=sentiment-api --tail=20` | Logs de todos os pods do conjunto, por label. |
| `kubectl top pods` | CPU e memória em uso por pod (o metrics-server já vem no AKS). |

### Azure CLI

| Comando | Para quê |
|---|---|
| `az aks create ...` | Criar o cluster (Etapa 4). |
| `az aks get-credentials -g RG -n CLUSTER` | Ensinar o `kubectl` a falar com o cluster. |
| `az aks scale -g RG -n CLUSTER --node-count 2` | Escalar nós, diferente de escalar pods, que é trabalho do `kubectl scale`. |
| `az aks stop` / `start -g RG -n CLUSTER` | Pausar o nó para economizar crédito sem destruir o cluster. |
| `az group delete -n NOME --yes --no-wait` | Faxina: apaga a pasta e tudo dentro dela. |

## Anexo B — O `deployment.yaml`, linha a linha

| Linha | O que ela diz ao cluster |
|---|---|
| `apiVersion: apps/v1` / `kind: Deployment` | Deployment não é um objeto do núcleo `v1` como o Pod: ele vive no grupo `apps`. Trocar essa linha é erro comum ao escrever do zero. |
| `spec:` / `replicas: 3` | O número que o ReplicaSet vai perseguir para sempre. Apagar um pod não muda este número, e é por isso que o pod volta. |
| `selector:` / `matchLabels:` / `app: sentiment-api` | Como o Deployment reconhece os pods que são dele. Precisa bater com as labels do `template` abaixo, ou o `apply` é recusado. |
| `strategy:` / `type: RollingUpdate` / `maxSurge: 1` / `maxUnavailable: 0` | Como trocar de versão: pode existir 1 pod a mais que o desejado durante a troca, e 0 a menos. Essa combinação garante capacidade total o tempo todo. A alternativa, `Recreate`, derruba tudo antes de subir a versão nova. |
| `template:` / `metadata:` / `labels:` / `app: sentiment-api` | Daqui para baixo é o `pod.yaml` da Aula 2, embutido. Todo pod criado nasce com estas labels, que são também o que o Service procura. |
| `spec:` / `containers:` / `- name: api` / `image: …sentiment-api:v2` | O nome `api` é o que você usa no `kubectl set image deployment/sentiment-api api=…` da Etapa 9. |
| `resources:` / `requests:` / `cpu: 100m` / `memory: 128Mi` / `limits: …` | `requests` é o que o scheduler reserva para decidir se o pod cabe no nó; `limits` é o teto que o container não pode ultrapassar. Sem requests, o cluster não tem como planejar, e é aí que aparece o `Insufficient cpu`. |
| `readinessProbe:` / `httpGet:` / `path: /health` / `port: 8000` | "Já pode receber tráfego?" Enquanto a resposta não for 200, o pod fica fora da lista de endpoints do Service. `initialDelaySeconds` é a carência inicial; `periodSeconds`, o intervalo entre perguntas. |
| `livenessProbe: …` | "Ainda está vivo?" Depois de `failureThreshold` falhas seguidas, o container é reiniciado. Uma liveness agressiva demais mata pods saudáveis sob carga: por isso a carência dela é maior que a da readiness. |

## Anexo C — Glossário

| Termo | Em uma frase |
|---|---|
| ReplicaSet | Mantém N pods iguais vivos: conta, cria e apaga até bater o número declarado. |
| Deployment | Gerencia ReplicaSets com histórico e estratégia de atualização. É o objeto que você escreve no dia a dia. |
| Template de pod | O molde de pod embutido no Deployment. Mudar o molde é o que dispara um novo ReplicaSet. |
| Rolling update | Troca de versão pod a pod, sem janela de manutenção; as duas versões coexistem por instantes. |
| Revisão | Cada estado já aplicado de um Deployment, guardado no histórico e recuperável com `rollout undo`. |
| maxSurge / maxUnavailable | Quantos pods a mais podem existir, e quantos a menos podem ficar prontos, durante um rollout. |
| Readiness probe | Pergunta "pode receber tráfego?". Enquanto não passar, o pod fica fora dos endpoints. |
| Liveness probe | Pergunta "ainda está vivo?". Falhou demais, o container é reiniciado. |
| Requests e limits | O que o pod reserva no nó e o teto que ele não pode passar. Base de toda decisão do scheduler. |
| Endpoints | A lista viva de IPs de pods prontos por trás de um Service. |
| HPA | Horizontal Pod Autoscaler: ajusta o número de réplicas sozinho, observando CPU ou outra métrica. Só teoria nesta aula. |
| Cluster autoscaler | Ajusta o número de nós do AKS. Escalar nós e escalar pods são coisas distintas. |
