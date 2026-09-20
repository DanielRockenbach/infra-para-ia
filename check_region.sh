#!/bin/bash
REGIAO=$1

echo "Tamanhos de VM liberados para esta assinatura em $REGIAO:"
az vm list-skus --location "$REGIAO" --resource-type virtualMachines --all -o json \
  | jq -r '.[] | select(.restrictions == []) | .name' | sort -u

echo ""
echo "Cota de vCPUs por família em $REGIAO:"
az vm list-usage --location "$REGIAO" -o table
