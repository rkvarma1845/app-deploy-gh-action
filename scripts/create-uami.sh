#!/bin/bash
# =============================================================================
# create-uami.sh
#
# PURPOSE
#   Creates (or reuses) a User Assigned Managed Identity so it is present
#   before the Bicep template runs.  Bicep references it as 'existing',
#   so the identity must already exist.
#
# USAGE
#   ./scripts/create-uami.sh \
#     --resource-group  <RESOURCE_GROUP> \
#     --location        <AZURE_REGION>   \
#     --identity-name   <UAMI_NAME>
#
# OUTPUTS
#   Sets GitHub Actions step outputs:
#     uami_name
#     uami_client_id
#     uami_principal_id
# =============================================================================

set -euo pipefail

RESOURCE_GROUP=""
LOCATION=""
IDENTITY_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --identity-name) IDENTITY_NAME="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

[[ -z "$RESOURCE_GROUP" ]] && exit 1
[[ -z "$LOCATION" ]] && exit 1
[[ -z "$IDENTITY_NAME" ]] && exit 1

echo "Creating UAMI: $IDENTITY_NAME"

az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

# Get details for pipeline
UAMI_NAME=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query name -o tsv)
UAMI_CLIENT_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query clientId -o tsv)
UAMI_PRINCIPAL_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query principalId -o tsv)

# ─── GitHub Actions outputs ─────────────────────────────
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "uami_name=$UAMI_NAME" >> "$GITHUB_OUTPUT"
  echo "uami_client_id=$UAMI_CLIENT_ID" >> "$GITHUB_OUTPUT"
  echo "uami_principal_id=$UAMI_PRINCIPAL_ID" >> "$GITHUB_OUTPUT"
fi
