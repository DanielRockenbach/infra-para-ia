# Aula 1 — Roteiro da prática: do código a uma API de IA no ar

**Missão da dupla:** em 1h30, colocar uma API de análise de sentimento no ar, acessível pela internet, usando apenas o navegador.

**O que vamos usar:** portal do Azure, Cloud Shell, Azure Container Registry (ACR) e Azure Container Instances (ACI).

> Convenção: substitua `SEUNOME` pelo seu nome, em letras minúsculas e sem acentos ou espaços (ex.: `acrmariasilva7`).

---

## Etapa 1 — Criar o resource group (portal)

1. Acesse [portal.azure.com](https://portal.azure.com) e faça login.
2. Na busca do topo, digite **Resource groups** e abra o serviço.
3. Clique em **+ Create**:
   - Resource group: `aula1-rg`
   - Region: **East US**
4. **Review + Create** → **Create**.

*Por que East US e não Brazil South? Custo menor e todos os serviços disponíveis. A latência não importa para o laboratório.*

## Etapa 2 — Abrir o Cloud Shell

1. Clique no ícone **`>_`** no topo do portal.
2. Escolha **Bash**.
3. Se for a primeira vez, aceite a criação do storage (opção "No storage account required" / efêmero, se oferecida, também serve para esta aula).

O Cloud Shell é um terminal Linux completo no navegador, já com `az`, `git` e `python` instalados. Nada precisa ser instalado no seu computador.

4. **Antes de seguir, rode estes dois comandos** (registram na sua assinatura os serviços que usaremos; é feito uma única vez e leva ~2 min em segundo plano):

```bash
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerInstance
```

Pode ir para a Etapa 3 sem esperar. Se mais adiante algum comando falhar com `MissingSubscriptionRegistration`, é só aguardar um minuto e repetir o comando que falhou.

## Etapa 3 — Clonar o projeto

```bash
git clone https://github.com/SEU-USUARIO-OU-ORG/infra-para-ia.git
cd infra-para-ia/aula1-containers
ls
```

Você deve ver: `api.py`, `modelo.pkl`, `treinar_modelo.py`, `requirements.txt`, `Dockerfile`, `ROTEIRO.md`.

## Etapa 4 — Entender o que vamos empacotar

```bash
cat api.py        # a API (FastAPI): recebe uma frase, responde o sentimento
cat Dockerfile    # a "receita" do container, linha a linha
```

Perguntas para discutir na dupla:

1. Qual é a imagem base do nosso container?
2. Por que o `requirements.txt` é copiado ANTES do restante do código?
3. Qual comando roda quando o container inicia?

## Etapa 5 — Criar o registry (ACR)

```bash
az acr create \
  --resource-group aula1-rg \
  --name acrSEUNOME \
  --sku Basic
```

⚠️ O nome do ACR é único no mundo e aceita apenas letras minúsculas e números. Se der "name already in use", acrescente números.

## Etapa 6 — Trazer a imagem para o seu registry

O build desta imagem acontece por **integração contínua**: a cada mudança no repositório, o GitHub Actions executa o Dockerfile e publica a imagem pronta no registry público do GitHub (GHCR). É assim que times profissionais trabalham: ninguém constrói imagem de produção na própria máquina. O professor vai mostrar o log desse build ao vivo (repositório → aba **Actions**): cada `Step` do log corresponde a uma linha do Dockerfile — são as camadas!

*(Por que não construímos direto no Azure? O comando de build do ACR é bloqueado em contas de avaliação gratuita, como medida antiabuso. Em uma assinatura corporativa, o mesmo fluxo funcionaria com `az acr build`.)*

Importe a imagem pública para o SEU registry privado:

```bash
az acr import \
  --name acrSEUNOME \
  --source ghcr.io/PROF-USUARIO/sentiment-api:v1 \
  --image sentiment-api:v1
```

Confira a imagem publicada no seu ACR:

```bash
az acr repository list --name acrSEUNOME --output table
```

A partir daqui, a imagem é sua: fica no seu registry, com suas credenciais, como se você mesmo a tivesse construído.

## Etapa 7 — Executar o container (ACI)

Primeiro, habilite e obtenha as credenciais do registry:

```bash
az acr update --name acrSEUNOME --admin-enabled true
az acr credential show --name acrSEUNOME
```

Agora crie o container (substitua usuário e senha pelos valores acima):

```bash
az container create \
  --resource-group aula1-rg \
  --name sentiment-api \
  --image acrSEUNOME.azurecr.io/sentiment-api:v1 \
  --registry-username acrSEUNOME \
  --registry-password 'SENHA-DO-COMANDO-ANTERIOR' \
  --ip-address Public \
  --ports 8000 \
  --cpu 1 --memory 1
```

Aguarde 1-2 minutos e pegue o IP público:

```bash
az container show \
  --resource-group aula1-rg \
  --name sentiment-api \
  --query ipAddress.ip --output tsv
```

## Etapa 8 — Testar a API

**No navegador:** abra `http://SEU-IP:8000/docs` — o FastAPI gera uma página de testes automática. Use o endpoint `POST /prediz`.

**Ou no Cloud Shell:**

```bash
curl -X POST http://SEU-IP:8000/prediz \
  -H "Content-Type: application/json" \
  -d '{"texto": "adorei o curso!"}'
```

Resposta esperada: `{"sentimento": "positivo", "confianca": 0.93...}`

**Experimentos para a dupla:**

1. Teste frases claramente negativas.
2. Teste uma frase irônica ("que maravilha, atrasou de novo"). O modelo acerta?
3. Teste uma frase em inglês. O que acontece e por quê?
4. Discutam: onde esse modelo simples falha, e o que seria preciso para melhorá-lo?

## Etapa 9 — Faxina final (OBRIGATÓRIA)

```bash
az group delete --name aula1-rg --yes --no-wait
```

Confirme no portal que o resource group `aula1-rg` sumiu (pode levar alguns minutos). Regra da disciplina: **infraestrutura de aula não dorme ligada.**

---

## Se algo der errado

| Sintoma | O que fazer |
|---|---|
| `az acr import` falha com "unauthorized" | A imagem no GHCR não está pública, ou a URL `ghcr.io/...` foi digitada errada. Avise o professor. |
| "TasksOperationsNotAllowed" | Você tentou `az acr build`: esse comando é bloqueado em contas gratuitas. Use o `az acr import` da Etapa 6. |
| Container não inicia | `az container logs --resource-group aula1-rg --name sentiment-api` |
| Página não abre | Confira IP e porta `:8000`; aguarde 1-2 min após o create; o endereço é `http://` (não `https://`). |
| "name already in use" no ACR | Escolha outro nome (acrescente números). |
| Comando negado / assinatura errada | `az account show` e, se preciso, `az account set --subscription "..."`. |

## Para levar para casa

O roteiro inteiro é repetível na sua conta, do zero, em ~20 minutos. Desafios opcionais (agora com o build nas SUAS mãos):

1. Faça um **fork** do repositório no seu GitHub e habilite a aba Actions. Todo push seu agora dispara o build da SUA imagem (`ghcr.io/SEU-USUARIO/sentiment-api`). Torne o pacote público (Packages → Package settings → Change visibility).
2. Mude a mensagem do endpoint `/` em `api.py`, faça push e acompanhe o build no Actions. Quantas camadas foram reaproveitadas do cache?
3. Acrescente 10 frases suas ao `treinar_modelo.py`, rode `python treinar_modelo.py`, commit e push. Depois importe a sua imagem para o seu ACR e atualize o container: você acabou de fazer um "deploy de modelo" com CI.
