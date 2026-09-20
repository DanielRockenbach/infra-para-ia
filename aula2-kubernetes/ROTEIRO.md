# Aula 2 — Roteiro da prática: Kubernetes I no AKS

Da assinatura vazia até a API de sentimento respondendo em um IP público, dentro de um cluster Kubernetes gerenciado pelo Azure. Cada etapa indica onde acontece (**portal**, **terminal** ou **navegador**), o comando exato e o que observar na resposta. O roteiro é autossuficiente: dá para refazer tudo em casa, quantas vezes quiser.

| | |
|---|---|
| **Tempo** | 2h em aula, em dupla. A Etapa 5 existe para ocupar a espera do `az aks create`. Em casa, com o caminho conhecido, sai em cerca de 40 minutos. |
| **Pré-requisitos** | Conta gratuita do Azure ativa (a mesma da Aula 1), navegador e a URL deste repositório. Nada para instalar: tudo roda no Cloud Shell. |
| **Custo** | Cerca de US$ 0,30. |

**Como ler as etapas:** PORTAL acontece clicando em [portal.azure.com](https://portal.azure.com). TERMINAL acontece no Cloud Shell (Bash), dentro do próprio portal. NAVEGADOR acontece em uma aba nova, no IP público da API. Os nomes de menus e botões aparecem em inglês, como no portal, com a tradução entre parênteses na primeira vez.

## Mapa da prática

| # | Etapa | # | Etapa |
|---|---|---|---|
| 1 | Resource group `aula2-rg` | 7 | Criar o Pod e observar |
| 2 | Cloud Shell e providers | 8 | Expor com um Service |
| 3 | Clonar o repositório | 9 | Testar no IP público |
| 4 | Criar o cluster AKS | 10 | Apagar o pod e observar |
| 5 | Ler o YAML do Pod | 11 | Faxina e custo |
| 6 | Conectar o kubectl | A | [Atividade da semana](ATIVIDADE.md) |

As etapas 1 a 4 são idênticas na Aula 3.

### Onde o crédito é consumido

```
Assinatura
├── Resource group aula2-rg                      ← criado por você
│   └── Cluster AKS aks-aula2                    control plane no tier Free: sem custo
└── Resource group MC_aula2-rg_aks-aula2_eastus  ← criado pelo AKS, sozinho
    ├── VM do nó · Standard_D2as_v7 · ~US$ 0,10/h
    ├── Load Balancer + IP público
    └── Disco e rede virtual do nó
```

Você cria um resource group; o AKS cria o segundo. Apagar `aula2-rg` no fim remove os dois.

---

## Parte 1 — Preparar o ambiente

Três etapas curtas que criam a pasta do exercício, abrem o terminal e trazem os arquivos. Idênticas nas duas aulas de Kubernetes.

### Etapa 1 — Criar o resource group `aula2-rg` · PORTAL

1. No portal, use a barra de busca do topo: digite **Resource groups** (Grupos de recursos) e abra o serviço.
2. Clique em **+ Create** (Criar).
3. Preencha apenas três campos: **Subscription** (assinatura), que já vem selecionada; **Resource group**, com o nome `aula2-rg`; e **Region** (região), com **(US) East US**.
4. **Review + create** (Revisar e criar) → **Create** (Criar). Em poucos segundos ele aparece na lista.

> **Por quê.** Todo recurso do Azure vive dentro de um resource group. Como tudo o que você criar hoje fica nesta pasta, a limpeza final é um comando só, e o risco de esquecer um recurso ligado consumindo crédito cai para quase zero. A região precisa ser a mesma do cluster: `eastus` é a que tem mais cota disponível em contas gratuitas.

### Etapa 2 — Abrir o Cloud Shell e registrar os providers · PORTAL + TERMINAL

1. Clique no ícone **`>_`** na barra superior do portal e escolha **Bash** (não PowerShell).
2. Se ele perguntar sobre armazenamento, escolha **No storage account required** (efêmero) com a sua assinatura; se essa opção não aparecer, aceite o storage padrão.
3. Confirme que o terminal está vivo e já autenticado: nenhum login é necessário.

```bash
az account show --output table
```

Em seguida registre os providers usados hoje. No Azure, o primeiro uso de cada família de serviços exige um registro único na assinatura; sem ele o `az aks create` falha com `MissingSubscriptionRegistration`. Rode agora e siga adiante: o registro roda em segundo plano, de 1 a 3 minutos.

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
# para conferir depois (deve responder Registered):
az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv
```

O Cloud Shell já vem com `az`, `git` e `kubectl` instalados. Depois de ~20 min de inatividade ele desconecta: basta clicar em **Reconnect**.

### Etapa 3 — Clonar o repositório · TERMINAL

```bash
git clone https://github.com/rodolfo-s-antunes/infra-para-ia.git
cd infra-para-ia/aula2-kubernetes
ls manifests/
```

Saída esperada:

```
exemplo-configmap.yaml   pod.yaml   service.yaml
```

São os dois manifestos da prática (`pod.yaml` e `service.yaml`) mais um exemplo de ConfigMap e Secret que ficou só na teoria. O código da API está em `api/`, mas hoje você não vai construir imagem nenhuma: a imagem já está pronta e pública no GHCR.

---

## Parte 2 — Criar o cluster

### Etapa 4 — Criar o cluster AKS · TERMINAL

```bash
az aks create \
  --resource-group aula2-rg \
  --name aks-aula2 \
  --location eastus \
  --node-count 1 \
  --node-vm-size Standard_D2as_v7 \
  --tier free \
  --generate-ssh-keys
```

Se o comando falhar em segundos com `The VM size of ... is not allowed in your subscription`, a sua conta ou região libera outros tamanhos. A mensagem é longa porque lista todos os permitidos. Para ler só os de 2 vCPUs, repita o comando com `2>&1 | grep -o "standard_d2[a-z_0-9]*" | sort -u` no final, escolha um deles e rode de novo com esse valor em `--node-vm-size`.

| Flag | O que ela decide |
|---|---|
| `--resource-group aula2-rg` | A pasta da Etapa 1. O cluster nasce dentro dela. |
| `--name aks-aula2` | Nome do cluster. Só precisa ser único no seu resource group. |
| `--node-count 1` | Uma máquina de trabalho. Em produção seriam três ou mais, em zonas diferentes. |
| `--node-vm-size Standard_D2as_v7` | 2 vCPU e 8 GB, ~US$ 0,10 por hora. É o menor tamanho que a conta gratuita permite para o AKS em eastus, e é o nó que aparece no `kubectl get nodes`. |
| `--tier free` | O control plane sai de graça. Você paga apenas o nó, o disco e o IP público. |
| `--generate-ssh-keys` | Cria um par de chaves para o nó, se você ainda não tiver. Não usaremos SSH. |

> **Enquanto o cluster sobe.** Não fique olhando o terminal. O comando devolve um bloco JSON gigante ao terminar, e nada acontece antes disso. Aproveite os 5 a 10 minutos para fazer a Etapa 5. Se a sessão cair no meio, tudo bem: a criação continua no Azure. Reconecte e confira com:
>
> ```bash
> az aks show -g aula2-rg -n aks-aula2 --query provisioningState -o tsv
> ```

### Etapa 5 — Ler e editar o manifesto do Pod · TERMINAL

```bash
cat manifests/pod.yaml
code manifests/pod.yaml    # ou: nano manifests/pod.yaml
```

Duas tarefas antes de aplicar qualquer coisa:

1. **Trocar a label `dupla: SUBSTITUA`** pelos nomes da dupla, em minúsculas e sem acento (por exemplo `ana-joao`). No `code`, salve com Ctrl+S e feche com Ctrl+Q; no `nano`, Ctrl+O e Ctrl+X.
2. **Conferir, sem alterar, duas linhas:** a `image` (de onde vem o container) e o `containerPort` (a porta que a API escuta dentro do pod).

Perguntas para a dupla:

1. Qual é o `kind` deste objeto e o que isso muda?
2. De onde vem a imagem, e quem a construiu?
3. Em que porta o uvicorn escuta dentro do container?
4. Quem promete manter este pod vivo?

O [Anexo B](#anexo-b--os-manifestos-linha-a-linha) traz este arquivo comentado linha a linha. Indentação em YAML é significativa: use espaços, nunca tabs.

### Etapa 6 — Conectar o kubectl ao cluster · TERMINAL

```bash
az aks get-credentials --resource-group aula2-rg --name aks-aula2
kubectl get nodes
kubectl get pods -A
```

Saída esperada (resumida):

```
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-xxxxxxxx-vmss000000   Ready    <none>   3m    v1.3x.x
# kubectl get pods -A: uma dezena de pods em kube-system (coredns, konnectivity,
# csi-azuredisk, metrics-server...) e nada no namespace default.
```

> **Por quê.** O `get-credentials` baixa o arquivo de configuração (`~/.kube/config`) que ensina o `kubectl` a falar com o API server do seu cluster. Daqui em diante, todo comando `kubectl` vale para qualquer Kubernetes do mundo: só este passo é específico do Azure. E note que o cluster já roda coisas antes de você: os pods de `kube-system` são o próprio Kubernetes se mantendo em pé.

**Confira no portal:** abra `aula2-rg` → `aks-aula2`. O **Status** deve estar **Succeeded (Running)**. O menu **Kubernetes resources** mostra pelo portal os mesmos objetos que o `kubectl get` lista no terminal: são duas portas para a mesma API.

---

## Parte 3 — Colocar a API no ar

### Etapa 7 — Criar o Pod e observar · TERMINAL

```bash
kubectl apply -f manifests/pod.yaml
kubectl get pods -w                       # Ctrl+C para sair
kubectl get pods -o wide --show-labels
kubectl describe pod sentiment-api
kubectl logs sentiment-api
kubectl exec -it sentiment-api -- curl -s localhost:8000/health
```

Saída esperada (resumida):

```
NAME            READY   STATUS    RESTARTS   AGE   IP           NODE
sentiment-api   1/1     Running   0          40s   10.244.0.x   aks-nodepool1-...
# describe, seção Events:
Scheduled → Pulling → Pulled → Created → Started
# logs: Uvicorn running on http://0.0.0.0:8000
# exec: {"status":"ok","modelo_carregado":true}
```

A sequência que você vai ver no `-w`: `Pending` → `ContainerCreating` → `Running`, com READY indo de `0/1` para `1/1`. O primeiro `Running` leva de alguns segundos a um minuto: é o tempo de baixar a imagem (140 MB) no nó.

Leia a seção **Events** do `describe` de cima para baixo: ela é o cluster contando o que fez, em ordem. O scheduler escolheu o nó, o kubelet baixou a imagem do GHCR, criou o container e o iniciou. Quando algo der errado nesta prática, é aqui que a explicação vai estar.

**Confira no portal:** abra o cluster → **Kubernetes resources** → **Workloads** → aba **Pods**. O `sentiment-api` aparece lá com o mesmo STATUS que o terminal mostrou. Clicando nele, a aba **YAML** mostra o seu manifesto acrescido de dezenas de campos que o cluster preencheu sozinho.

### Etapa 8 — Expor a API com um Service LoadBalancer · TERMINAL

```bash
cat manifests/service.yaml
kubectl apply -f manifests/service.yaml
kubectl get svc sentiment-api -w     # até EXTERNAL-IP sair de <pending>
kubectl get endpoints sentiment-api
```

Saída esperada (resumida):

```
NAME            TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)
sentiment-api   LoadBalancer   10.0.x.x      <pending>       80:3xxxx/TCP
sentiment-api   LoadBalancer   10.0.x.x      20.xx.xxx.xxx   80:3xxxx/TCP
# endpoints: 10.244.0.x:8000   (o IP do pod da Etapa 7)
```

O IP público leva de alguns segundos a 3 minutos para aparecer: nesse tempo o Azure está criando um load balancer de verdade e apontando para o seu nó. **Se o campo ENDPOINTS voltar vazio, o Service não encontrou nenhum pod:** o `selector` dele não bate com as `labels` do pod. Esse é o erro mais comum da aula, e ele não gera mensagem de erro nenhuma.

O `kubectl get endpoints` imprime um `Warning` dizendo que o objeto Endpoints está deprecado desde o Kubernetes 1.33. Ignore: a lista continua correta. O substituto moderno é `kubectl get endpointslices -l kubernetes.io/service-name=sentiment-api`, que mostra a mesma informação em outro formato.

O caminho de uma requisição:

```
navegador / curl          Service sentiment-api          Pod sentiment-api
http://20.xx.xxx.xxx  →   type: LoadBalancer         →   labels:
porta 80                  port: 80 → targetPort: 8000        app: sentiment-api
                          selector:                          dupla: ana-joao
                            app: sentiment-api           container api · uvicorn :8000
```

O Service não conhece o pod pelo nome nem pelo IP: ele procura, a cada instante, quem tem a label `app: sentiment-api`. Label igual ao selector, tráfego chega. Diferente, silêncio.

### Etapa 9 — Testar a API · TERMINAL + NAVEGADOR

```bash
IP=$(kubectl get svc sentiment-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $IP
curl http://$IP/versao
curl http://$IP/hostname
curl -X POST http://$IP/prediz \
  -H "Content-Type: application/json" \
  -d '{"texto": "adorei o curso!"}'
```

Saída esperada (resumida):

```
{"versao":"v2"}
{"hostname":"sentiment-api"}
{"sentimento":"positivo","confianca":0.93...}
```

No navegador, abra `http://SEU-IP/docs` (atenção: `http://`, sem o "s"). A interface do FastAPI permite testar o `POST /prediz` pelo botão **Try it out**. Repare que agora a porta é a 80, e não a 8000 da Aula 1: quem faz a tradução de 80 para 8000 é o Service.

Vale gastar dois minutos testando os limites do modelo, como na Aula 1: uma frase negativa, uma frase irônica ("que maravilha, atrasou de novo") e uma em inglês. O `/hostname` hoje responde sempre o mesmo nome, porque existe um pod só. Na Aula 3 ele passa a ser a prova visual do load balancing.

### Etapa 10 — Apagar o pod e ver o que acontece · TERMINAL

```bash
kubectl delete pod sentiment-api
kubectl get pods
curl -m 5 http://$IP/versao     # desiste após 5 s: não há mais ninguém atrás do IP
kubectl get svc sentiment-api   # o Service continua lá, com IP
kubectl get endpoints sentiment-api   # ... e a lista ficou vazia
```

**O pod não volta.** Ninguém foi encarregado de recriá-lo: um Pod é um objeto solto, e apagar é exatamente o que você pediu. O Service continua existindo, com IP público e tudo, mas com a lista de endpoints vazia: um endereço sem ninguém atrás.

Discussão na dupla, para guardar até a próxima aula: que objeto deveria ter recriado esse pod? E se houvesse três pods, o Service teria continuado respondendo?

---

## Parte 4 — Custo e faxina

### Etapa 11 — Apagar tudo · TERMINAL + PORTAL

**Não saia da aula sem fazer esta etapa.** Um cluster esquecido ligado consome cerca de US$ 2,50 por dia do seu crédito, e o IP público continua reservado. Antes de apagar, colete as capturas de tela que a [atividade da semana](ATIVIDADE.md) pede.

```bash
az group delete --name aula2-rg --yes --no-wait
```

Pelo portal o caminho equivalente é **Resource groups** (Grupos de recursos) → `aula2-rg` → **Delete resource group** (Excluir grupo de recursos), digitando o nome para confirmar. Depois de 5 a 15 minutos (o `MC_...` sai primeiro; o `aula2-rg` pode levar mais de 10 minutos), confira na lista que os dois grupos sumiram: o seu `aula2-rg` e o `MC_aula2-rg_aks-aula2_eastus` que o AKS criou. Se você optou pelo Cloud Shell com storage, um grupo pequeno `cloud-shell-storage-…` permanece: custa centavos por mês e pode ficar.

Para ver o que a prática custou, busque **Cost Management** → **Cost analysis**. O consumo aparece com atraso de algumas horas até um dia, então volte amanhã: o esperado é algo em torno de US$ 0,30. Recomendado: em **Cost Management** → **Budgets**, crie um alerta de US$ 20 na sua assinatura.

Recibo estimado da prática:

| Item | Custo |
|---|---|
| Control plane do AKS (tier Free) | US$ 0,00 |
| 1 nó Standard_D2as_v7 · 2h | ~US$ 0,20 |
| Load Balancer e IP público · 2h | ~US$ 0,06 |
| **Total** | **~US$ 0,30** |

### Checklist final da prática

- [ ] Resource group `aula2-rg` criado em East US
- [ ] Providers registrados sem erro
- [ ] Repositório clonado no Cloud Shell
- [ ] Cluster `aks-aula2` em Succeeded
- [ ] Label `dupla` editada no `pod.yaml`
- [ ] `kubectl get nodes` mostra 1 nó Ready
- [ ] Pod `sentiment-api` em Running 1/1
- [ ] Events do `describe` lidos até Started
- [ ] Service com EXTERNAL-IP atribuído
- [ ] `/prediz` respondeu no IP público
- [ ] Pod apagado e Service órfão observado
- [ ] Capturas da atividade coletadas
- [ ] `az group delete` executado
- [ ] Os dois resource groups sumiram da lista

---

## Erros comuns

Ordem de investigação, sempre: `get` para ver o estado, `describe` para ler os eventos, `logs` só depois.

| Sintoma | O que rodar | Causa provável e saída |
|---|---|---|
| `MissingSubscriptionRegistration` | `az provider register --namespace <o do erro>` | A Etapa 2 não terminou. Espere 2 minutos até o estado ficar Registered e repita o comando. |
| `az aks create` falha com `VM size ... is not allowed in your subscription` | leia a lista de tamanhos no próprio erro; `az vm list-usage --location eastus -o table` mostra as cotas | A conta gratuita só libera alguns tamanhos por região. Escolha um `standard_d2..._v7` da lista, por exemplo `Standard_D2as_v7` ou `Standard_D2s_v7`. Se persistir, avise o professor. |
| Pod em `ImagePullBackOff` | `kubectl describe pod sentiment-api` | Nome ou tag da imagem digitados errado no YAML. A seção Events mostra a linha exata do erro. |
| Pod parado em `Pending` | `kubectl get nodes` / `kubectl describe pod sentiment-api` | O nó ainda não está Ready, ou não há recurso livre para agendar o pod. |
| EXTERNAL-IP `<pending>` por mais de 3 min | `kubectl describe svc sentiment-api` | Cota de IP público esgotada ou provisionamento lento. Alternativa: `kubectl port-forward svc/sentiment-api 8080:80` e testar em `localhost:8080`. |
| `curl` no IP não responde | `kubectl get endpoints sentiment-api` | Lista vazia: o `selector` do Service não bate com as `labels` do pod. Compare as duas linhas nos YAML. |
| `kubectl` diz que não conecta | `az aks get-credentials -g aula2-rg -n aks-aula2` | Sessão nova do Cloud Shell sem storage: o kubeconfig se foi. Repita a Etapa 6. |
| YAML recusado com `mapping values are not allowed` | `cat -A manifests/pod.yaml` | Indentação com tab ou dois pontos sem espaço depois. YAML só aceita espaços. |
| Cloud Shell "desconectou" | Botão **Reconnect** | Normal após ~20 min de inatividade. Com shell efêmero, clone o repositório de novo (Etapa 3). |

---

## Anexo A — Comandos de referência

### Azure CLI (`az`): fala com o Azure

| Comando | Para quê |
|---|---|
| `az account show -o table` | Confirmar em qual assinatura você está. |
| `az group create -n NOME -l eastus` | A Etapa 1 pela linha de comando. |
| `az aks create ...` | Criar o cluster (Etapa 4). |
| `az aks show -g RG -n CLUSTER --query provisioningState -o tsv` | Saber se o cluster terminou de subir. |
| `az aks get-credentials -g RG -n CLUSTER` | Ensinar o `kubectl` a falar com o cluster. |
| `az aks stop` / `az aks start -g RG -n CLUSTER` | Pausar o nó para não gastar crédito, sem destruir o cluster. |
| `az group delete -n NOME --yes --no-wait` | Faxina: apaga a pasta e tudo dentro dela. |

### `kubectl`: fala com o cluster

| Comando | Para quê |
|---|---|
| `kubectl apply -f ARQUIVO.yaml` | Declarar o estado desejado. Rodar duas vezes não duplica nada. |
| `kubectl get pods -o wide --show-labels` | Listar pods com IP, nó e labels. |
| `kubectl get pods -w` | Assistir às mudanças de estado ao vivo (Ctrl+C para sair). |
| `kubectl get pods -l app=sentiment-api` | Filtrar por label: o mesmo mecanismo que o Service usa. |
| `kubectl describe pod NOME` | Ver tudo sobre o objeto, incluindo a seção Events. |
| `kubectl logs NOME` / `kubectl logs -f NOME` | A saída do container. Equivale ao `docker logs`. |
| `kubectl exec -it NOME -- bash` | Um shell dentro do container. Equivale ao `docker exec`. |
| `kubectl get svc,endpoints` | O Service e a lista de pods que ele encontrou. O Warning de deprecação do Endpoints pode ser ignorado. |
| `kubectl get all -n NAMESPACE` | Panorama de um namespace. |
| `kubectl delete -f ARQUIVO.yaml` | Apagar exatamente o que aquele arquivo criou. |
| `kubectl explain pod.spec` | A documentação de cada campo, sem sair do terminal. |

## Anexo B — Os manifestos, linha a linha

### `manifests/pod.yaml`

| Linha | O que ela diz ao cluster |
|---|---|
| `apiVersion: v1` | Qual versão da API do Kubernetes descreve este objeto. Pod e Service são tão antigos que vivem na `v1`. |
| `kind: Pod` | O tipo do objeto. Trocar esta palavra troca completamente o significado do arquivo. |
| `metadata:` / `name: sentiment-api` | O nome do pod, único no namespace. É por ele que você chama `logs`, `describe` e `delete`. |
| `labels:` / `app: sentiment-api` / `dupla: SUBSTITUA` | Etiquetas livres, chave e valor. Não fazem nada sozinhas: servem para outros objetos (o Service) e para você (`-l`) encontrarem este pod. Troque `SUBSTITUA` pelos nomes da dupla. |
| `spec:` / `containers:` / `- name: api` | A lista de containers do pod. Aqui um só, chamado `api`. O nome reaparece em comandos como `kubectl set image`. |
| `image: ghcr.io/rodolfo-s-antunes/sentiment-api:v2` | A imagem pronta, pública no GitHub Container Registry. O Kubernetes não constrói imagens: ele baixa esta. |
| `ports:` / `- containerPort: 8000` | Documenta a porta que o uvicorn escuta dentro do container. É o número que o Service vai usar como `targetPort`. |

### `manifests/service.yaml`

| Linha | O que ela diz ao cluster |
|---|---|
| `kind: Service` | Um endereço estável na frente de um conjunto de pods. |
| `spec:` / `type: LoadBalancer` | Peça um IP público ao provedor de nuvem. É esta linha que faz o Azure criar um load balancer de verdade e cobrar por ele. As alternativas são `ClusterIP` (só dentro do cluster) e `NodePort`. |
| `selector:` / `app: sentiment-api` | A regra de busca: todo pod com esta label entra na lista de destinos. Se não bater com o `pod.yaml`, o Service fica sem endpoints e o `curl` não responde. |
| `ports:` / `- port: 80` / `targetPort: 8000` | Quem chega bate na porta 80 do IP público; o Service entrega na 8000 do container. É por isso que a URL da Aula 1 tinha `:8000` e a de hoje não tem nada. |

## Anexo C — Glossário

| Termo | Em uma frase |
|---|---|
| Cluster | O conjunto de máquinas onde seus containers rodam, mais o cérebro que decide o que roda onde. |
| Nó (node) | Uma máquina do cluster. Na prática, uma VM Standard_D2as_v7 criada pelo AKS. |
| Control plane | O cérebro: API server, etcd, scheduler e controllers. No AKS, o Azure cuida dele por você. |
| Manifesto | Um arquivo YAML que descreve o estado desejado. Sempre tem `apiVersion`, `kind`, `metadata` e `spec`. |
| Pod | A menor unidade que o Kubernetes agenda: um ou mais containers que compartilham rede e armazenamento. É efêmero e não volta sozinho. |
| Label e selector | Etiqueta chave/valor em um objeto, e a regra que procura objetos por etiqueta. A cola de todo o Kubernetes. |
| Service | Nome e IP estáveis na frente dos pods que casam com o selector. Tipos: ClusterIP, NodePort, LoadBalancer. |
| Endpoints | A lista viva de IPs de pods prontos que um Service encontrou. Vazia significa selector errado. |
| Namespace | Pasta lógica dentro do cluster. `default` é onde você trabalha; `kube-system` é do cluster. |
| ReplicaSet | O objeto que mantém N pods iguais vivos, recriando o que morre. Assunto da Aula 3. |
| Deployment | Gerencia ReplicaSets com histórico e estratégia de atualização. É o objeto do dia a dia. Aula 3. |
| Reconciliação | O loop que compara estado desejado com estado atual e corrige a diferença, para sempre. |
| AKS | Kubernetes gerenciado do Azure. Equivalentes: EKS na AWS, GKE no Google Cloud. |
