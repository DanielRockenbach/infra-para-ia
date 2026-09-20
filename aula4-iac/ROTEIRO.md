# Aula 4 — Roteiro da prática: Infraestrutura como Código com Terraform

Nas três primeiras aulas você criou infraestrutura clicando no portal e digitando comandos `az`. Funciona, mas não deixa rastro: ninguém sabe exatamente o que você criou, ninguém revisa antes, e refazer amanhã depende da sua memória. Hoje o mesmo container da Aula 1 passa a viver em um arquivo. Na primeira metade da prática você roda o Terraform na sua mão, no Cloud Shell, e vê o estado nascer ao lado do código. Na segunda metade o Terraform sai da sua mão e vai para o GitHub Actions, que aplica a infraestrutura a partir de um pull request revisado. Cada etapa indica onde acontece (**terminal**, **github** ou **navegador**), o comando exato e o que observar na resposta.

| | |
|---|---|
| **Tempo** | 1h30 em aula, em dupla. A Parte 1 é a base conceitual e sai em cerca de 40 minutos. A Parte 2 é o fluxo de trabalho de verdade. Refazendo em casa: cerca de 1 hora. |
| **Pré-requisitos** | Conta gratuita do Azure ativa, as práticas das Aulas 1 a 3 feitas, e um fork deste repositório com a aba Actions habilitada, o mesmo fork da atividade da Aula 1. |
| **Custo** | Centavos. Cerca de US$ 0,06. |

**Como ler as etapas:** TERMINAL acontece no Cloud Shell (Bash), dentro do portal. GITHUB acontece no seu fork, em [github.com](https://github.com). NAVEGADOR acontece em uma aba nova, no endereço público da API.

## Mapa da prática

| # | Etapa | # | Etapa |
|---|---|---|---|
| 1 | Preparar e ler o Terraform | 6 | Sincronizar o fork e colar as credenciais |
| 2 | `init`, `plan`, `apply` | 7 | O pull request e o plano no log |
| 3 | Trocar a imagem e ver a recriação | 8 | Merge, apply e a API no ar |
| 4 | `destroy` | 9 | O segundo pull request, v3 |
| 5 | `bootstrap` | 10 | Faxina em duas camadas |
| | | A | [Atividade da semana](ATIVIDADE.md) |

Da 1 à 4 o Terraform roda na sua mão, com o estado em um arquivo local. Da 5 à 10 quem roda é o robô, com o estado guardado no Azure.

### Onde o crédito é consumido

```
Assinatura
├── Resource group aula4-rg                ← criado pelo Terraform
│   └── Container group sentiment-api      1 vCPU, 1 GB · ~US$ 0,02/h
└── Resource group tfstate-rg              ← criado pelo bootstrap.sh
    └── Storage account tfstateXXXXXXXX    guarda o estado · centavos por mês
```

A identidade do robô, o service principal, não custa nada. Ela não aparece em resource group nenhum, porque vive no Entra ID, e é por isso que a faxina dela é um passo separado.

---

## Parte 1 — O Terraform na sua mão

### Etapa 1 — Preparar e ler o Terraform · TERMINAL

Abra o Cloud Shell (ícone **`>_`** na barra do topo, modo **Bash**) e traga o material novo:

```bash
cd infra-para-ia && git pull && cd aula4-iac
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform version
ls
code terraform.tfvars
```

Se a pasta `infra-para-ia` não existir no seu Cloud Shell, use `git clone https://github.com/rodolfo-s-antunes/infra-para-ia.git` e entre nela.

> **Por que o `export`.** O provider do Azure na linha 4.x não adivinha mais em qual assinatura trabalhar: ele exige a variável de ambiente `ARM_SUBSCRIPTION_ID`. O `export` vale só para a aba atual do Cloud Shell. Se você abrir outra aba ou a sessão cair, repita o comando, senão o `plan` reclama com `subscription_id is a required provider property`.

No editor que abriu, troque `SUADUPLA` pelo apelido da dupla, salve com **Ctrl+S** e feche com **Ctrl+Q**. O apelido aceita só letras minúsculas e dígitos, de 3 a 12 caracteres, sem espaço nem hífen. **Mude apenas o que está entre aspas**, sem mexer nos espaços em volta do sinal de igual, porque na Parte 2 o robô vai conferir a formatação do arquivo.

Quem prefere a linha de comando pode fazer o mesmo sem abrir o editor, trocando `anaejoao` pelo apelido de vocês:

```bash
sed -i 's/dupla = "SUADUPLA"/dupla = "anaejoao"/' terraform.tfvars
cat terraform.tfvars
```

O `ls` mostrou um arquivo a mais que os do repositório: o `.terraform.lock.hcl`. Ele guarda a versão exata do provider e a impressão digital do pacote baixado, e está versionado de propósito. É o que garante que a sua máquina, a do colega e o robô do GitHub usem o mesmo provider, byte a byte. Em Terraform, "funciona na minha máquina" costuma ser um lock file que ninguém comitou.

Leia o `main.tf` junto com a turma antes de rodar qualquer coisa:

```bash
cat main.tf
```

Procure quatro coisas, nesta ordem: 1) o bloco `locals`, que define as tags uma vez e reaproveita em todo recurso, 2) o `azurerm_resource_group`, que é a pasta que você criou clicando na Aula 1, 3) o `random_string`, que não existe no Azure e só vive no estado, 4) o `azurerm_container_group`, que é o `az container create` da Aula 1 em forma de arquivo. Repare que o container group se refere ao resource group por `azurerm_resource_group.rg.name`, e não pelo texto `"aula4-rg"`. É essa referência que ensina ao Terraform em que ordem criar as coisas.

Perguntas para a dupla: quantos recursos este arquivo cria? Por que o `dns_name_label` precisa de um sufixo aleatório? O que acontece com esse sufixo se você rodar `apply` duas vezes?

### Etapa 2 — `init`, `plan`, `apply` · TERMINAL

```bash
terraform init
terraform plan
terraform apply
terraform output
terraform state list
curl -s $(terraform output -raw url_api)/versao
```

O `apply` mostra o plano de novo e para, esperando você digitar `yes`. **Leia o plano antes de digitar.** É o hábito mais importante da aula.

O `plan` termina com:

```
Plan: 3 to add, 0 to change, 0 to destroy.
```

e o `apply` com `Apply complete! Resources: 3 added.`, seguido dos três outputs. O `curl` responde `{"versao":"v2"}`. Se ele responder `connection refused`, espere 30 segundos e repita: o `apply` termina quando o Azure aceita o recurso, não quando a API termina de subir.

O `terraform state list` devolve três linhas:

```
azurerm_container_group.api
azurerm_resource_group.rg
random_string.sufixo
```

Esse é o seu primeiro contato com o estado. Ele é um arquivo, o `terraform.tfstate`, que apareceu na pasta depois do `apply`. Dentro dele está o mapa entre o que você escreveu e o que existe no Azure, incluindo o sufixo aleatório, que não pode ser descoberto olhando a nuvem. Apagar esse arquivo não apaga a infraestrutura: apaga a memória dela, que é bem pior.

Rode o `plan` de novo, sem mudar nada:

```bash
terraform plan
```

Agora ele diz `No changes. Your infrastructure matches the configuration.` Isso é idempotência: aplicar o mesmo arquivo dez vezes tem o mesmo efeito de aplicar uma vez. Foi o que o `kubectl apply` fez na Aula 3, e é a diferença entre declarar o resultado e mandar executar um passo.

> **Confira no portal.** Busque **Resource groups**, abra `aula4-rg` e clique em `sentiment-api`. Na aba **Tags** estão `gerenciado_por: terraform`, `aula: 4`, `dupla: <o apelido de vocês>` e `turma: 2026-2`. Em infraestrutura de verdade essa primeira tag é o que separa o que pode ser mexido na mão do que não pode.

### Etapa 3 — Trocar a imagem e ver a recriação · TERMINAL

```bash
sed -i 's/imagem_tag = "v2"/imagem_tag = "v3"/' terraform.tfvars
terraform plan
terraform apply
curl -s $(terraform output -raw url_api)/versao
```

O plano agora traz um sinal novo, o `-/+`, e a explicação na linha da imagem:

```
  # azurerm_container_group.api must be replaced
-/+ resource "azurerm_container_group" "api" {
      ~ image = "ghcr.io/rodolfo-s-antunes/sentiment-api:v2" -> "ghcr.io/rodolfo-s-antunes/sentiment-api:v3" # forces replacement

Plan: 1 to add, 0 to change, 1 to destroy.
```

`forces replacement` quer dizer que a imagem de um container group não pode ser trocada no lugar: para mudar, o Azure exige apagar e criar de novo. O `~` sozinho, que você vai ver na seção "para ir além", seria uma alteração sem recriação.

Depois do `apply`, o `curl` responde `{"versao":"v3"}`. Compare os dois outputs: o **IP mudou** e a **URL não**, porque o rótulo DNS continua o mesmo e o sufixo aleatório continua guardado no estado. Só por isso o `curl` da linha seguinte funciona sem você precisar copiar nada.

Compare com a Aula 3: lá o rolling update trocou a imagem sem derrubar a API, porque o Kubernetes subia o pod novo antes de tirar o velho. Aqui há cerca de um minuto fora do ar. A diferença não é o Terraform, é o recurso: uma Container Instance é uma coisa só, e não um conjunto de réplicas.

### Etapa 4 — `destroy` · TERMINAL

```bash
terraform destroy
az group list -o table
```

Leia o plano, que agora diz `Plan: 0 to add, 0 to change, 3 to destroy.`, e digite `yes`. O `az group list` já não mostra o `aula4-rg`.

> **Por que destruir agora.** A Parte 2 vai criar os mesmos nomes a partir do GitHub, com outro estado, guardado no Azure. Se o `aula4-rg` ainda existir, o robô falha com `already exists`: ele não sabe que aquele grupo é seu, porque o estado dele é novo e está vazio. Dois estados apontando para o mesmo recurso é um dos jeitos clássicos de se machucar com Terraform.

---

## Parte 2 — O Terraform no robô

Da Etapa 5 em diante nada mais roda na sua mão. Quem aplica é o GitHub Actions, e para isso ele precisa de duas coisas que o Terraform não pode criar para si mesmo: um lugar para guardar o estado e uma identidade para falar com o Azure. Criar essas duas coisas é o que se chama de bootstrap.

### Etapa 5 — `bootstrap` · TERMINAL

```bash
./bootstrap.sh
```

O script leva cerca de um minuto e imprime no fim um bloco para você copiar. **Não feche essa aba.**

O que ele fez, nas três partes que ele mesmo anuncia:

1. Um resource group `tfstate-rg` e dentro dele uma storage account com um container de blobs chamado `tfstate`. É aí que o estado vai morar, em vez de ficar em um arquivo na sua pasta. Ele liga o versionamento do blob, que guarda o histórico do estado sem custo relevante.
2. Um service principal com papel **Contributor** na assinatura inteira. Service principal é uma conta de robô: tem identidade e senha, mas não tem pessoa atrás. É ela que o GitHub Actions usa para criar recursos no seu lugar.
3. O arquivo `bootstrap.out.json`, que contém a senha desse robô.

> **Contributor na assinatura inteira é generoso demais para produção.** Em um ambiente real o robô receberia o papel só no resource group em que ele trabalha, e o resource group seria criado antes, por outra pessoa. Aqui ele precisa poder criar o próprio `aula4-rg`, e a assinatura é de vocês e vai ser esvaziada no fim da aula, então o escopo largo é aceitável. Esse ajuste de escopo é o que RBAC significa na prática.

Guarde a diferença entre as duas coisas que o script pede para você colar no GitHub:

| | Secret | Variable |
|---|---|---|
| Vale para | `AZURE_CREDENTIALS` | `TFSTATE_STORAGE_ACCOUNT` |
| O GitHub mostra depois de salvo? | Não, nunca mais | Sim |
| Aparece no log? | Mascarado como `***` | Em texto puro |
| Por quê | É a senha do robô | É só o nome de uma storage account |

O `bootstrap.out.json` tem a senha do robô. Ele não vai para o repositório (o `.gitignore` da pasta cuida disso), não vai para o chat da dupla e não entra em captura de tela. Para rever depois: `cat bootstrap.out.json`.

### Etapa 6 — Sincronizar o fork e colar as credenciais · GITHUB

**A ordem importa.** Primeiro traga o material da aula 4 para o seu fork, depois configure as credenciais.

1. Abra o seu fork, o mesmo da atividade da Aula 1, em `github.com/SEU-USUARIO/infra-para-ia`.
2. Clique em **Sync fork** e em **Update branch**. Agora a pasta `aula4-iac/` e os dois workflows novos existem no seu fork.
3. Vá em **Settings** → **Secrets and variables** → **Actions**.
4. Na aba **Secrets**, **New repository secret**: nome `AZURE_CREDENTIALS`, valor o bloco JSON inteiro que o bootstrap imprimiu, da primeira `{` até a última `}`.
5. Na aba **Variables**, **New repository variable**: nome `TFSTATE_STORAGE_ACCOUNT`, valor o nome da storage account que o bootstrap imprimiu.

Espere cerca de um minuto antes de disparar o primeiro workflow, para a permissão do service principal terminar de propagar no Azure.

> **Se você sincronizar o fork antes de configurar as credenciais**, os jobs aparecem na aba Actions como **skipped**, em cinza. Isso é de propósito: os dois jobs só começam quando a variable `TFSTATE_STORAGE_ACCOUNT` existe. Um job cinza aqui não é erro, é o workflow evitando falhar por um motivo que você ainda não tinha como resolver.

### Etapa 7 — O pull request e o plano no log · GITHUB

Agora a mudança de infraestrutura vira uma proposta revisável, em vez de um comando digitado por alguém.

1. No seu fork, abra `aula4-iac/terraform.tfvars`.
2. Clique no ícone de lápis, **Edit this file**.
3. Troque `SUADUPLA` pelo apelido da dupla, o mesmo da Parte 1. **Mude só o que está entre aspas.**
4. Clique em **Commit changes...**.
5. Marque **Create a new branch for this commit and start a pull request** e dê à branch o nome `dupla-<apelido>`.
6. **Propose changes**.
7. **Create pull request**.

> **Confira o repositório base antes de criar.** Na tela do pull request, à esquerda do título, o GitHub mostra algo como `base repository: rodolfo-s-antunes/infra-para-ia ← head repository: SEU-USUARIO/infra-para-ia`. O padrão do GitHub é propor a mudança para o repositório original, e não é isso que você quer: o repositório do professor não tem as suas credenciais, e o job vai aparecer como skipped. Clique em **base repository** e escolha **SEU-USUARIO/infra-para-ia**. As duas pontas do pull request têm que ser o seu fork.

Alguns segundos depois, o quadro de checks aparece no fim do pull request. Há dois caminhos para ler o plano, e vale conhecer os dois:

1. **Pelo pull request.** No quadro de checks, clique em **Details** ao lado de `terraform-aula4 / plan`, e depois no passo **terraform plan** para expandi-lo. A última linha é o resumo.
2. **Pela aba Summary.** Na página do run, clique em **Summary** na barra da esquerda. O workflow escreve ali o resumo em negrito e a saída completa dentro de um bloco recolhível.

Os passos do log vêm recolhidos por padrão, e é isso que faz muita gente jurar que o plano não aparece. A lupa no canto do log aceita busca: procure por `Plan:` e ele pula direto para a linha.

O plano esperado é `Plan: 3 to add, 0 to change, 0 to destroy.`, os mesmos três recursos da Etapa 2. O estado do robô está vazio, porque é um estado novo, no Azure, e não aquele arquivo local que você destruiu na Etapa 4.

Perguntas para a dupla: por que o plano diz 3, e não 1, se você só editou uma linha? O que apareceria aqui se um colega tivesse aplicado alguma coisa antes de você?

### Etapa 8 — Merge, apply e a API no ar · GITHUB e NAVEGADOR

1. No pull request, **Merge pull request** e depois **Confirm merge**.
2. Vá para a aba **Actions**. O workflow `terraform-aula4` está rodando de novo, agora com o job **apply** em vez do `plan`.
3. Abra o job e acompanhe. Depois do `terraform apply` vem o passo **Teste de fumaça e resumo**, que fica batendo em `/versao` até a API responder.

O merge foi o `yes` que você digitou na Etapa 2. A diferença é que desta vez a aprovação ficou registrada, com autor, data e o plano que estava na tela no momento em que foi aprovada.

Quando o job terminar em verde, abra a aba **Summary** do run. Ela traz a URL da API e a resposta de `/versao`. Copie a URL, cole no navegador acrescentando `/docs` no fim, e teste o `POST /prediz` pela interface do FastAPI, como na Aula 1.

> **Confira no portal.** O `aula4-rg` está de volta, com as mesmas tags, mas desta vez ninguém digitou `apply` em terminal nenhum. Confira também `tfstate-rg` → a storage account → **Containers** → `tfstate`: o arquivo `aula4.terraform.tfstate` está lá, e a aba de versões mostra o histórico das aplicações.

### Etapa 9 — O segundo pull request, v3 · GITHUB

Se o tempo apertar, esta etapa fica para casa.

Repita a Etapa 7 mudando agora só `imagem_tag`, de `v2` para `v3`, em uma branch chamada `v3-<apelido>`. O plano do pull request traz o `-/+` e o `forces replacement` da Etapa 3, e é aí que está a graça: o revisor vê que a mudança vai recriar o recurso **antes** de aprovar. Foi exatamente essa informação que faltou em todo incidente de produção que começou com alguém mudando um atributo aparentemente inofensivo.

Depois do merge, o job `apply` recria o container e o teste de fumaça devolve `{"versao":"v3"}` na aba Summary.

---

## Parte 3 — Faxina

### Etapa 10 — Faxina em duas camadas · GITHUB e TERMINAL

**Não saia da aula sem fazer esta etapa.** Colete antes as capturas que a [atividade da semana](ATIVIDADE.md) pede, porque depois do destroy não há como recuperar a URL nem o log com o plano.

A primeira camada apaga o que o Terraform criou, e quem faz isso é o próprio Terraform:

```
Actions → terraform-aula4-destroy → Run workflow → confirmacao: destruir → Run workflow
```

O campo de confirmação existe para que um clique distraído não derrube nada: qualquer palavra diferente de `destruir` e o job nem começa.

A segunda camada apaga o que o Terraform não criou, e essa é sua:

```bash
./bootstrap-limpeza.sh
az group list -o table
```

O script avisa se o `aula4-rg` ainda existir, sinal de que você pulou a primeira camada. No fim, a lista de resource groups não tem nem `aula4-rg` nem `tfstate-rg`. Se você optou pelo Cloud Shell com storage, o grupo `cloud-shell-storage-...` continua e pode ficar, como nas aulas anteriores.

Falta um passo manual, que nenhum script pode fazer por você: apague o secret `AZURE_CREDENTIALS` em **Settings** → **Secrets and variables** → **Actions** do seu fork. O robô que ele identificava não existe mais, e um segredo órfão é um segredo que ninguém vai lembrar de revogar.

### Checklist final da prática

- [ ] `ARM_SUBSCRIPTION_ID` exportado no Cloud Shell
- [ ] `terraform.tfvars` editado com o apelido da dupla
- [ ] `main.tf` lido com a turma antes do primeiro apply
- [ ] `apply` local concluído com `3 added` e `/versao` respondendo `v2`
- [ ] Tags conferidas no portal, com `gerenciado_por: terraform`
- [ ] `plan` repetido mostrando `No changes`
- [ ] Troca para `v3` com `forces replacement` no plano, e IP novo com a mesma URL
- [ ] `destroy` local concluído e `aula4-rg` fora da lista
- [ ] `bootstrap.sh` rodado e a saída copiada para o GitHub
- [ ] Secret e variable configurados no fork
- [ ] Pull request aberto **contra o próprio fork**, com o plano lido no log e na aba Summary
- [ ] Merge feito e job `apply` verde, com a API respondendo no navegador
- [ ] Capturas da atividade coletadas
- [ ] Workflow de destroy rodado, `bootstrap-limpeza.sh` rodado e o secret apagado

---

## Erros comuns

| Sintoma | O que rodar ou olhar | Causa comum e correção |
|---|---|---|
| `subscription_id is a required provider property` | `export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)` | Faltou o export nesta aba do Cloud Shell. A variável não sobrevive a uma aba nova nem a uma reconexão. |
| `Invalid value for variable "dupla"` | editar `terraform.tfvars` | O marcador `SUADUPLA` ainda está lá, ou o apelido tem maiúscula, espaço ou hífen. A validação está no `variables.tf` e é de propósito. |
| Passo `terraform fmt` vermelho no pull request | `terraform fmt` no Cloud Shell, ou refazer a edição pelo navegador | A edição mexeu nos espaços em volta do sinal de igual. Mude só o que está entre aspas. |
| `MissingSubscriptionRegistration` | `az provider register --namespace <o do erro>` | Provider de recurso nunca registrado nesta assinatura. Aguarde o estado `Registered` e rode o plan de novo. |
| `Error acquiring the state lock` | esperar o outro job terminar, ou `terraform force-unlock <ID>` | Um plan de pull request e um apply da main ao mesmo tempo, ou um job cancelado no meio. O lock é o que impede dois Terraform de escreverem o mesmo estado. |
| Apply falha com `already exists` | `az group delete -n aula4-rg --yes` e depois **Re-run jobs** | O destroy da Etapa 4 não foi feito, e o grupo existe sem estar no estado do robô. |
| Job `plan` ou `apply` aparece como `skipped` | Settings → Secrets and variables → Actions, aba Variables | A variable `TFSTATE_STORAGE_ACCOUNT` não foi criada ou está com o nome errado. Confira também se o pull request tem o seu fork nas duas pontas. |
| `AuthorizationFailed` ou `InvalidAuthenticationToken` | conferir o secret e esperar 1 a 2 minutos | JSON colado incompleto, ou o papel do service principal ainda não propagou. Recolar o JSON inteiro resolve o primeiro caso. |
| Não acho o plano no log | job `plan`, passo `terraform plan`, ou a aba Summary | Os passos vêm recolhidos por padrão. A lupa do log aceita buscar por `Plan:`. |
| `curl` responde `connection refused` | esperar 30 segundos e repetir | O container ainda está baixando a imagem. O apply termina quando o Azure aceita o recurso, não quando a API responde. |

---

## Para ir além, opcional, em casa

Três exercícios independentes, para quem quiser ir além do que coube em 1h30.

**1. Drift.** Com a infraestrutura de pé pelo Cloud Shell, vá ao portal e apague o container `sentiment-api` na mão, deixando o resource group. Depois:

```bash
terraform plan
```

Ele mostra `Plan: 1 to add, 0 to change, 0 to destroy.`, porque comparou o que está escrito com o que existe de verdade e achou a diferença. Um `terraform apply` traz o container de volta. Variante mais sutil: em vez de apagar, altere uma tag pelo portal e rode o plan de novo, que agora mostra `~ update in-place`, sem recriação. Isso é drift, a diferença entre o que o código diz e o que o mundo é, e é por isso que times sérios rodam `plan` em horário programado só para conferir.

**2. Operar o estado remoto a partir do Cloud Shell.** Crie na mão um `backend_ci.tf` com o mesmo conteúdo que o workflow gera, exporte as quatro variáveis `ARM_` a partir do `bootstrap.out.json` e rode:

```bash
terraform init -reconfigure
terraform plan
```

Se estiver tudo certo, o plan responde `No changes`, porque agora você está lendo o mesmo estado que o robô escreveu. É assim que se investiga um apply que falhou no CI. Lembre de apagar o `backend_ci.tf` depois, já que ele está no `.gitignore` justamente para não ser versionado.

**3. OIDC em vez de senha.** O `AZURE_CREDENTIALS` guarda uma senha de robô, que não expira sozinha e vaza se alguém colar no lugar errado. O caminho moderno é a federação de identidade: o GitHub emite um token de curta duração para aquele repositório e aquela branch, e o Azure confia nele sem que exista senha nenhuma guardada.

```bash
APP_ID=$(az ad app create --display-name gh-oidc-infra-para-ia --query appId -o tsv)
az ad sp create --id "$APP_ID"
az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/$(az account show --query id -o tsv)"
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "gh-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<SEU-USUARIO>/infra-para-ia:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

Falta ainda uma segunda credencial federada com o `subject` terminando em `:pull_request`, para o job de plan, e no workflow a permissão `id-token: write`, a variável `ARM_USE_OIDC=true` e `ARM_CLIENT_ID`, `ARM_TENANT_ID` e `ARM_SUBSCRIPTION_ID` como variables, sem secret nenhum.

> **Aviso.** Estes comandos são material de referência, não foram ensaiados em aula e não têm suporte na atividade avaliativa. Se você quebrar alguma coisa tentando, o caminho de volta é o `bootstrap-limpeza.sh` e um bootstrap novo.

---

## Anexo A — Comandos de referência

### Terraform

| Comando | Para quê |
|---|---|
| `terraform init` | Baixar os providers e preparar a pasta. Roda uma vez por pasta, e de novo quando o backend muda. |
| `terraform init -reconfigure` | Trocar de backend sem tentar migrar o estado anterior. |
| `terraform fmt` | Formatar os arquivos. Com `-check`, só avisa, sem alterar, que é o que o workflow faz. |
| `terraform validate` | Conferir se a configuração faz sentido, sem falar com o Azure. |
| `terraform plan` | Mostrar o que aconteceria. Não muda nada. Com `-out=arquivo`, salva o plano. |
| `terraform apply` | Aplicar. Sem argumento, mostra o plano e pede confirmação. Com um plano salvo, aplica exatamente aquele. |
| `terraform destroy` | Apagar tudo o que está no estado. |
| `terraform output` | Ver os outputs. Com `-raw nome`, devolve o valor puro, pronto para usar em um `curl`. |
| `terraform state list` | Listar o que o estado conhece. |
| `terraform show` | Ver o estado inteiro em detalhe, ou um plano salvo. |
| `terraform providers lock` | Preencher o `.terraform.lock.hcl` para outras plataformas. |
| `terraform force-unlock <ID>` | Soltar um lock preso depois de um job cancelado. Confira antes que não há ninguém aplicando. |

### Azure CLI

| Comando | Para quê |
|---|---|
| `az account show --query id -o tsv` | O id da assinatura, que vira o `ARM_SUBSCRIPTION_ID`. |
| `az group list -o table` | Conferir a faxina. |
| `az ad sp create-for-rbac ...` | Criar a identidade do robô (Etapa 5, dentro do bootstrap). |
| `az ad sp list --display-name gh- -o table` | Achar service principals criados pelo bootstrap. |
| `az storage account list -g tfstate-rg -o table` | Achar a storage account do estado. |
| `az group delete -n NOME --yes --no-wait` | Faxina de emergência, quando o Terraform já perdeu o estado. |

---

## Anexo B — Glossário

| Termo | Em uma frase |
|---|---|
| IaC | Infraestrutura como Código: a infraestrutura descrita em arquivos versionados, revisados e aplicados por ferramenta, em vez de criada por cliques. |
| Declarativo | Você escreve o resultado desejado e a ferramenta descobre os passos. O oposto é imperativo, que é a sequência de comandos `az` das aulas anteriores. |
| Provider | O plugin que sabe conversar com uma nuvem ou serviço. O `azurerm` traduz os seus blocos em chamadas da API do Azure. |
| Resource | Um bloco `resource` é uma coisa que passa a existir. Cada um tem um endereço próprio, como `azurerm_resource_group.rg`. |
| Plan | A simulação: o que seria criado, alterado ou destruído. Ler o plano antes de aplicar é o hábito central do Terraform. |
| Apply | A execução do plano. Com um plano salvo, aplica exatamente o que estava na tela, sem recalcular. |
| Estado | O arquivo que guarda o mapa entre o código e os recursos reais, incluindo o que não dá para descobrir olhando a nuvem. Perder o estado é perder a memória, não a infraestrutura. |
| Backend | Onde o estado mora. Local, na sua pasta, na Parte 1. Remoto, em um blob do Azure, na Parte 2. |
| Lock | A trava que impede dois Terraform de escreverem o mesmo estado ao mesmo tempo. O backend do Azure usa o lease do próprio blob. |
| Lock file | O `.terraform.lock.hcl`, que fixa a versão e a impressão digital dos providers. Coisa diferente do lock de estado, apesar do nome parecido. |
| Drift | A diferença entre o que o código declara e o que existe de fato, em geral porque alguém mexeu na mão pelo portal. |
| Idempotência | Aplicar o mesmo arquivo várias vezes tem o mesmo efeito de aplicar uma vez. É o que faz o segundo `plan` dizer `No changes`. |
| Service principal | Conta de robô no Entra ID: tem identidade e credencial, não tem pessoa atrás. É quem o GitHub Actions usa para agir no Azure. |
| RBAC | O modelo de permissões do Azure: quem (a identidade) pode fazer o quê (o papel) e onde (o escopo). Na aula, Contributor na assinatura. |
| OIDC | Federação de identidade: o CI apresenta um token de curta duração em vez de uma senha guardada. É o caminho recomendado hoje, e está na seção "para ir além". |
| Bootstrap | O que precisa existir antes do Terraform poder trabalhar e que ele não cria para si mesmo: o lugar do estado e a identidade que aplica. |
| GitOps | Usar o Git como fonte da verdade da infraestrutura: a mudança entra por pull request, é revisada, e o merge é o que dispara a aplicação. É o que a Parte 2 faz. |
