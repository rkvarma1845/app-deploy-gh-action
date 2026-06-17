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

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
die() { echo "[$(date -u '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

RESOURCE_GROUP=""
LOCATION=""
IDENTITY_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location)       LOCATION="$2";       shift 2 ;;
    --identity-name)  IDENTITY_NAME="$2";  shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -z "$RESOURCE_GROUP" ]]  && die "--resource-group is required"
[[ -z "$LOCATION" ]]        && die "--location is required"
[[ -z "$IDENTITY_NAME" ]]   && die "--identity-name is required"

# ─── Ensure Resource Group exists ────────────────────────────────────────────
log "Ensuring Resource Group '$RESOURCE_GROUP' exists in '$LOCATION'..."
az group create \
  --name     "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
log "Resource Group ready."

# ─── Create or reuse UAMI ────────────────────────────────────────────────────
log "Creating (or reusing) User Assigned Identity '$IDENTITY_NAME'..."
az identity create \
  --name           "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location       "$LOCATION" \
  --output none

UAMI_NAME=$(az identity show \
  --name           "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query name -o tsv)

UAMI_CLIENT_ID=$(az identity show \
  --name           "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query clientId -o tsv)

UAMI_PRINCIPAL_ID=$(az identity show \
  --name           "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)

log "UAMI ready:"
log "  Name         : $UAMI_NAME"
log "  Client ID    : $UAMI_CLIENT_ID"
log "  Principal ID : $UAMI_PRINCIPAL_ID"

# ─── Export as GitHub Actions step outputs ───────────────────────────────────
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "uami_name=${UAMI_NAME}"           >> "$GITHUB_OUTPUT"
  echo "uami_client_id=${UAMI_CLIENT_ID}" >> "$GITHUB_OUTPUT"
  echo "uami_principal_id=${UAMI_PRINCIPAL_ID}" >> "$GITHUB_OUTPUT"
  log "Step outputs written to GITHUB_OUTPUT."
fi
