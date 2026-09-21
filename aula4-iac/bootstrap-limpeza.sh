#!/usr/bin/env bash
# Desfaz o bootstrap: apaga o resource group do estado (que leva junto a
# storage account e a identidade do robô) e a permissão que sobrou.
# Rode depois do workflow terraform-aula4-destroy.
set -euo pipefail

if [[ ! -f bootstrap.out ]]; then
  echo "Não encontrei bootstrap.out. Rode este script de dentro de aula4-iac." >&2
  exit 1
fi
# shellcheck source=/dev/null
source bootstrap.out

if az group show -n aula4-rg &>/dev/null; then
  echo "Atenção: o resource group aula4-rg ainda existe."
  echo "O caminho certo é rodar antes o workflow terraform-aula4-destroy,"
  echo "para o Terraform apagar o que ele mesmo criou."
  read -r -p "Apagar aula4-rg assim mesmo? (digite sim para confirmar) " resposta
  if [[ "$resposta" == "sim" ]]; then
    az group delete -n aula4-rg --yes --no-wait
  fi
fi

echo "Apagando a permissão do robô na assinatura"
az role assignment delete --assignee "$PRINCIPAL_ID" --role Contributor \
  --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}" 2>/dev/null || true

echo "Apagando o resource group do estado: ${RG_ESTADO} (leva a storage account e a identidade)"
az group delete -n "$RG_ESTADO" --yes --no-wait

rm -f bootstrap.out

echo
echo "Feito. Se quiser, apague também as quatro variables do fork em"
echo "Settings > Secrets and variables > Actions. Elas não contêm segredo."
