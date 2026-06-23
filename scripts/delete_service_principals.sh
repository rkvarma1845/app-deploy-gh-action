#!/usr/bin/env bash
# Deletes Azure Service Principals by display name
# Usage: Edit CLIENT_NAMES below, then run: bash delete_service_principals.sh

# ── INPUT: Same list used to create SPs ──────────────────────────────────────
CLIENT_NAMES=(
    "client-one"
    "client-two"
    "client-three"
    "client-four"
    "client-five"
    "client-six"
    "client-seven"
    "client-eight"
)
# ─────────────────────────────────────────────────────────────────────────────

if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI not found."; exit 1
fi
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged in. Run: az login"; exit 1
fi

echo "Deleting ${#CLIENT_NAMES[@]} service principal(s)..."
echo ""

for name in "${CLIENT_NAMES[@]}"; do
    app_id=$(az ad sp list --display-name "$name" --query "[0].appId" -o tsv 2>/dev/null)

    if [[ -z "$app_id" ]]; then
        echo "NOT FOUND: '$name' — skipping"
    else
        az ad app delete --id "$app_id" 2>/dev/null
        echo "DELETED: '$name' (appId: $app_id)"
    fi
done

echo ""
echo "Done."