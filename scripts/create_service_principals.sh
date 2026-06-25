#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Script Name: create_service_principals.sh
#
# Description:
#   Creates Azure Service Principals in Microsoft Entra ID for a list of clients.
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
#   3. Adds prefix "renigne-" and appends environment name
#   4. Checks whether Service Principal already exists
#   5. Creates Service Principal if not found
#   6. Prints clientId, clientSecret and principalId
#
# Prerequisites:
#   - Azure CLI installed
#   - Logged into Azure (az login)
#   - jq installed
#
# How to execute:
#   chmod +x scripts/create_service_principals.sh      
#
#   CLIENTS=("client-one" "client-two" "client-three")
#
#   bash create_service_principals.sh dev "${CLIENTS[@]}"
# -----------------------------------------------------------------------------

PREFIX="rengine"

# First argument = environment
ENV_NAME=$1

# Remove first argument so remaining args are clients
shift

# Check inputs
if [ -z "$ENV_NAME" ]; then
    echo "Usage: bash create_sp.sh <env> client1 client2 ..."
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "No client names provided"
    exit 1
fi


declare -a clientNames=()
declare -a clientIds=()
declare -a clientSecrets=()
declare -a clientPrincipalIds=()

# Azure login check
if ! az account show &>/dev/null; then
    echo "Run az login first"
    exit 1
fi


for client in "$@"; do

    # Format: sp-clientname-env
    name="${PREFIX}-${client}-${ENV_NAME}"

    existing=$(az ad sp list --display-name "$name" --query "[0].appId" -o tsv 2>/dev/null)

    if [[ -n "$existing" ]]; then
        echo "EXISTS: $name"
        continue
    fi

    echo "CREATING: $name"

    sp=$(az ad sp create-for-rbac --name "$name" --output json 2>&1 | grep -v "^WARNING")

    app_id=$(echo "$sp" | jq -r '.appId')
    secret=$(echo "$sp" | jq -r '.password')
    principal_id=$(az ad sp show --id "$app_id" --query id -o tsv)

    clientNames+=("$name")
    clientIds+=("$app_id")
    clientSecrets+=("$secret")
    clientPrincipalIds+=("$principal_id")

done

echo ""
# ── Print summary lists ───────────────────────────────────────────────────────
echo "============================================"
echo " CREDENTIALS SUMMARY"
echo "============================================"
echo ""

join_array() {
    local out=""
    for i in "$@"; do
        [[ -n "$out" ]] && out+=", "
        out+="$i"
    done
    echo "$out"
}

printf "%-24s = [%s]\n" "clientNames"        "$(join_array "${clientNames[@]}")"
printf "%-24s = [%s]\n" "clientIds"          "$(join_array "${clientIds[@]}")"
printf "%-24s = [%s]\n" "clientSecrets"      "$(join_array "${clientSecrets[@]}")"
printf "%-24s = [%s]\n" "clientPrincipalIds" "$(join_array "${clientPrincipalIds[@]}")"

echo ""
echo "NOTE: Azure does not store secrets after creation."