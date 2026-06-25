#!/usr/bin/env bash
# =============================================================================
# delete_resources.sh
#
# Deletes all resources in a given Azure Resource Group EXCEPT ACR
#
# Usage:
#   bash delete_resources.sh <resource-group-name>
#
# Example:
#   bash delete_resources.sh nodejs-app-rg
#
# What it does:
#   1. Takes resource group name as argument
#   2. Lists all resources except ACR (Microsoft.ContainerRegistry/registries)
#   3. Deletes each resource one by one
#
# How to execute:
#   chmod +x scripts/delete_resources.sh nodejs-app-rg
#
#   bash delete_resources.sh dev "${CLIENTS[@]}"
# =============================================================================

# ── Input ─────────────────────────────────────────────────────────────────────
RESOURCE_GROUP="$1"

# ── Validate input ────────────────────────────────────────────────────────────
if [[ -z "$RESOURCE_GROUP" ]]; then
    echo "Usage: bash delete_resources.sh <resource-group-name>"
    exit 1
fi

echo "Resource Group : $RESOURCE_GROUP"
echo "Deleting all resources except ACR..."
echo ""

# ── List all resources except ACR and delete them ─────────────────────────────
# --query filters out Microsoft.ContainerRegistry/registries type
# xargs passes each resource id to az resource delete one by one
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?type!='Microsoft.ContainerRegistry/registries'].id" \
  -o tsv | \
  xargs -I {} az resource delete --ids {} --verbose

echo ""
echo "Done."