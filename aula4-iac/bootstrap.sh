#!/usr/bin/env bash
# Cria o que fica fora do Terraform: a storage account que guarda o estado
# remoto e a identidade que o GitHub Actions usa para falar com o Azure.
#
# Rode uma vez, a partir da pasta aula4-iac, no Cloud Shell.
# Para desfazer: ./bootstrap-limpeza.sh
set -euo pipefail

LOCATION="eastus"
RG_ESTADO="tfstate-rg"
REPO="infra-para-ia"

if [[ -f bootstrap.out ]]; then
  echo "Já existe um bootstrap.out nesta pasta." >&2
  echo "Rode ./bootstrap-limpeza.sh antes de refazer o bootstrap." >&2
  exit 1
fi

SUB_ID=$(az account show --query id -o tsv)

# O tr leva SIGPIPE quando o head fecha a entrada, e com pipefail ligado isso
# derrubaria o script. O || true preserva os 8 caracteres que o head já leu.
SUFIXO=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 8 || true)
SA="tfstate${SUFIXO}"
NOME_SP="gh-${REPO}-${SUFIXO}"

echo "1/3 Resource group do estado: ${RG_ESTADO}"
az group create -n "$RG_ESTADO" -l "$LOCATION" \
  --tags gerenciado_por=bootstrap aula=4 -o none

echo "2/3 Storage account do estado: ${SA}"
az storage account create -n "$SA" -g "$RG_ESTADO" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false -o none

CHAVE=$(az storage account keys list -g "$RG_ESTADO" -n "$SA" --query '[0].value' -o tsv)
az storage container create -n tfstate --account-name "$SA" --account-key "$CHAVE" -o none

# Versionamento do blob: histórico do estado, sem custo relevante
az storage account blob-service-properties update \
  --account-name "$SA" -g "$RG_ESTADO" --enable-versioning true -o none

echo "3/3 Identidade do robô: ${NOME_SP} (papel Contributor na assinatura)"
az ad sp create-for-rbac --name "$NOME_SP" --role Contributor \
  --scopes "/subscriptions/${SUB_ID}" --json-auth > bootstrap.out.json
APP_ID=$(jq -r .clientId bootstrap.out.json)

cat > bootstrap.out <<EOF
TFSTATE_STORAGE_ACCOUNT=${SA}
APP_ID=${APP_ID}
SUB_ID=${SUB_ID}
RG_ESTADO=${RG_ESTADO}
EOF

echo
echo "========= COPIE PARA O GITHUB ========="
echo "Settings > Secrets and variables > Actions, no SEU fork"
echo
echo "Aba Variables > New repository variable"
echo "  Nome:  TFSTATE_STORAGE_ACCOUNT"
echo "  Valor: ${SA}"
echo
echo "Aba Secrets > New repository secret"
echo "  Nome:  AZURE_CREDENTIALS"
echo "  Valor: o bloco JSON abaixo, inteiro, da primeira { até a última }"
echo
cat bootstrap.out.json
echo
echo "Este JSON contém clientSecret. Ele não vai para o repositório,"
echo "não vai para o chat da dupla e não entra em captura de tela."
echo "Para rever depois: cat bootstrap.out.json"
echo
echo "Aguarde cerca de 1 minuto antes do primeiro workflow, para a"
echo "permissão do service principal propagar."
