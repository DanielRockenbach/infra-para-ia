#!/usr/bin/env bash
# Desfaz o bootstrap: apaga a storage account do estado e a identidade
# do robô. Rode depois do workflow terraform-aula4-destroy.
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

echo "Apagando o resource group do estado: ${RG_ESTADO}"
az group delete -n "${RG_ESTADO}" --yes --no-wait

echo "Apagando a identidade do robô: ${APP_ID}"
az ad sp delete --id "${APP_ID}" 2>/dev/null || true
az ad app delete --id "${APP_ID}" 2>/dev/null || true

rm -f bootstrap.out bootstrap.out.json

echo
echo "Feito. Falta um passo manual no seu fork:"
echo "apague o secret AZURE_CREDENTIALS em Settings > Secrets and variables > Actions."
echo "O robô que ele identificava não existe mais."
