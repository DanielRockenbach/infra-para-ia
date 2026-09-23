#!/usr/bin/env bash
# Cria o que fica fora do Terraform: a storage account que guarda o estado
# remoto e a identidade que o GitHub Actions usa para falar com o Azure.
#
# A identidade é uma identidade gerenciada com credencial federada para o
# GitHub (OIDC). Ela não tem senha: o GitHub prova quem é a cada execução e
# o Azure aceita. Nada de segredo em lugar nenhum.
#
# Rode uma vez, a partir da pasta aula4-iac, no Cloud Shell:
#   ./bootstrap.sh SEU-USUARIO-DO-GITHUB
# Para desfazer: ./bootstrap-limpeza.sh
set -euo pipefail

LOCATION="brazilsouth"
RG_ESTADO="tfstate-rg"
REPO="infra-para-ia"
GH_USER="${1:-}"

if [[ -z "$GH_USER" ]]; then
  echo "Uso: ./bootstrap.sh SEU-USUARIO-DO-GITHUB" >&2
  echo "É o usuário dono do fork, o que aparece em github.com/USUARIO/${REPO}." >&2
  exit 1
fi
if [[ -f bootstrap.out ]]; then
  echo "Já existe um bootstrap.out nesta pasta." >&2
  echo "Rode ./bootstrap-limpeza.sh antes de refazer o bootstrap." >&2
  exit 1
fi
if az group show -n "$RG_ESTADO" &>/dev/null; then
  echo "O resource group ${RG_ESTADO} já existe, de um bootstrap anterior." >&2
  echo "Apague com: az group delete -n ${RG_ESTADO} --yes" >&2
  exit 1
fi

# Os IDs numéricos do dono e do repositório entram no subject do token OIDC.
# São públicos e vêm da API do GitHub.
REPO_JSON=$(curl -fsS "https://api.github.com/repos/${GH_USER}/${REPO}") || {
  echo "Não encontrei github.com/${GH_USER}/${REPO}. Confira o usuário e se o fork existe." >&2
  exit 1
}
REPO_ID=$(echo "$REPO_JSON" | jq -r .id)
OWNER_ID=$(echo "$REPO_JSON" | jq -r .owner.id)

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
# O tr leva SIGPIPE quando o head fecha a entrada, e com pipefail ligado isso
# derrubaria o script. O || true preserva os 8 caracteres que o head já leu.
SUFIXO=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 8 || true)
SA="tfstate${SUFIXO}"
IDENTIDADE="gh-${REPO}"

echo "1/4 Resource group do estado: ${RG_ESTADO} em ${LOCATION}"
az group create -n "$RG_ESTADO" -l "$LOCATION" \
  --tags gerenciado_por=bootstrap aula=4 -o none

echo "2/4 Storage account do estado: ${SA}"
az storage account create -n "$SA" -g "$RG_ESTADO" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false -o none
CHAVE=$(az storage account keys list -g "$RG_ESTADO" -n "$SA" --query '[0].value' -o tsv)
az storage container create -n tfstate --account-name "$SA" --account-key "$CHAVE" -o none
az storage account blob-service-properties update \
  --account-name "$SA" -g "$RG_ESTADO" --enable-versioning true -o none

echo "3/4 Identidade do robô: ${IDENTIDADE} (papel Contributor na assinatura)"
az identity create -g "$RG_ESTADO" -n "$IDENTIDADE" -l "$LOCATION" -o none
CLIENT_ID=$(az identity show -g "$RG_ESTADO" -n "$IDENTIDADE" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show -g "$RG_ESTADO" -n "$IDENTIDADE" --query principalId -o tsv)
# A identidade leva alguns segundos para aparecer no Entra ID, e a atribuição
# de papel falha com PrincipalNotFound se for feita cedo demais. Tenta de novo.
for tentativa in 1 2 3 4 5 6; do
  if az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal --role Contributor \
    --scope "/subscriptions/${SUB_ID}" -o none 2>/dev/null; then
    break
  fi
  if [[ $tentativa -eq 6 ]]; then
    echo "Não consegui dar o papel Contributor à identidade ${IDENTIDADE}." >&2
    echo "Rode ./bootstrap-limpeza.sh e tente de novo." >&2
    exit 1
  fi
  echo "    a identidade ainda está propagando, tentando de novo em 10s"
  sleep 10
done

echo "4/4 Credenciais federadas para github.com/${GH_USER}/${REPO}"
SUJEITO="repo:${GH_USER}@${OWNER_ID}/${REPO}@${REPO_ID}"
for par in "gh-main:ref:refs/heads/main" "gh-pr:pull_request"; do
  NOME="${par%%:*}"
  FIM="${par#*:}"
  az identity federated-credential create --identity-name "$IDENTIDADE" -g "$RG_ESTADO" \
    -n "$NOME" --issuer https://token.actions.githubusercontent.com \
    --subject "${SUJEITO}:${FIM}" --audiences api://AzureADTokenExchange -o none
done

cat > bootstrap.out <<EOF
TFSTATE_STORAGE_ACCOUNT=${SA}
AZURE_CLIENT_ID=${CLIENT_ID}
AZURE_TENANT_ID=${TENANT_ID}
AZURE_SUBSCRIPTION_ID=${SUB_ID}
PRINCIPAL_ID=${PRINCIPAL_ID}
RG_ESTADO=${RG_ESTADO}
EOF

echo
echo "========= COPIE PARA O GITHUB ========="
echo "No SEU fork: Settings > Secrets and variables > Actions > aba Variables"
echo "Crie quatro variables com New repository variable, uma por linha:"
echo
echo "  TFSTATE_STORAGE_ACCOUNT   ${SA}"
echo "  AZURE_CLIENT_ID           ${CLIENT_ID}"
echo "  AZURE_TENANT_ID           ${TENANT_ID}"
echo "  AZURE_SUBSCRIPTION_ID     ${SUB_ID}"
echo
echo "Nenhum desses valores é segredo. Para rever depois: cat bootstrap.out"
echo "Dê um intervalo entre o fim deste script e o primeiro workflow,"
echo "para a permissão do robô propagar."
