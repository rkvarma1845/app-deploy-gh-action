#!/usr/bin/env bash
# Creates Azure Service Principals for a list of client names (no role assigned)
# If SP already exists, fetches its details (secret not retrievable from Azure)
# Usage: Edit CLIENT_NAMES below, then run: bash create_service_principals.sh

# ── INPUT: Define your client names here ─────────────────────────────────────
CLIENT_NAMES=(
    "client-one"
)
# ─────────────────────────────────────────────────────────────────────────────

# Parallel credential arrays (index-aligned with CLIENT_NAMES)
declare -a clientNames=()
declare -a clientIds=()
declare -a clientSecrets=()
declare -a clientPrincipalIds=()

# ── Prereq check ──────────────────────────────────────────────────────────────
if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI not found. Install from https://aka.ms/installazurecli"; exit 1
fi
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged in. Run: az login"; exit 1
fi

# ── Create or fetch SPs ───────────────────────────────────────────────────────
for name in "${CLIENT_NAMES[@]}"; do

    existing=$(az ad sp list --display-name "$name" --query "[0].appId" -o tsv 2>/dev/null)

    if [[ -n "$existing" ]]; then
        echo "EXISTS: '$name'"
    else
        echo "CREATE: '$name'"
        sp=$(az ad sp create-for-rbac --name "$name" --output json 2>&1 | grep -v "^WARNING")
        app_id=$(echo "$sp" | jq -r '.appId')
        secret=$(echo "$sp" | jq -r '.password')
        principal_id=$(az ad sp show --id "$app_id" --query id -o tsv 2>/dev/null)
        echo "  clientId    : $app_id"
        echo "  principalId : $principal_id"
        echo ""

        clientNames+=("$name")
        clientIds+=("$app_id")
        clientSecrets+=("$secret")
        clientPrincipalIds+=("$principal_id")
    fi

    
done

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