#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Script Name: delete_service_principals.sh
#
# Description:
#   Deletes Azure Service Principals from Microsoft Entra ID for a list of clients.
#
# Naming Convention:
#   rengine-<client-name>-<environment>
#
# Example:
#   client-one →  renigne-client-one-dev
#
# What this script does:
#   1. Accepts environment name as first argument
#   2. Accepts list of client names as remaining arguments
#   3. Reconstructs Service Principal name using naming convention
#   4. Checks whether Service Principal exists
#   5. Deletes Azure Application + Service Principal
#
# Prerequisites:
#   - Azure CLI installed
#   - Logged into Azure (az login)
#
# How to execute:
#   chmod +x scripts/delete_service_principals.sh      
#
#   CLIENTS=("client-one" "client-two" "client-three")
#
#   bash delete_service_principals.sh dev "${CLIENTS[@]}"
#
# Example deleted names:
#   sp-client-one-dev
#   sp-client-two-dev
# -----------------------------------------------------------------------------

set -euo pipefail

# Usage:
# bash delete_sp.sh dev client1 client2 client3

PREFIX="rengine"

# First arg = environment
ENV_NAME=$1

# Remove first arg, remaining = clients
shift

if [ -z "$ENV_NAME" ]; then
    echo "Usage: bash delete_sp.sh <env> client1 client2 ..."
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "No client names provided"
    exit 1
fi

# Checks
if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI not found"
    exit 1
fi

if ! az account show &>/dev/null; then
    echo "ERROR: Run az login first"
    exit 1
fi


echo "Deleting service principals..."
echo ""

for client in "$@"; do

    # Same naming convention as create script
    name="${PREFIX}-${client}-${ENV_NAME}"

    app_id=$(az ad sp list \
        --display-name "$name" \
        --query "[0].appId" \
        -o tsv 2>/dev/null)

    if [[ -z "$app_id" ]]; then
        echo "NOT FOUND: $name — skipping"
        continue
    fi

    # Delete app + SP in :contentReference[oaicite:0]{index=0} Entra ID
    az ad app delete --id "$app_id" 2>/dev/null

    echo "DELETED: $name (appId: $app_id)"

done

echo ""
echo "Done."