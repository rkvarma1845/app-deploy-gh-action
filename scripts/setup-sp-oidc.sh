#!/usr/bin/env bash

# chmod +x scripts/setup-sp-oidc.sh
# ./scripts/setup-sp-oidc.sh \
#   --app-name        sp-gh-action \
#   --resource-group  nodejs-app-rg \
#   --gh-org          rkvarma1845 \
#   --gh-repo         app-deploy-gh-action \
#   --gh-env          main


set -euo pipefail

# ─── Input ────────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 --app-name <name> --resource-group <rg> --gh-org <org> --gh-repo <repo> --gh-env <env>"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --app-name)        APP_NAME=$2;       shift 2 ;;
    --resource-group)  RESOURCE_GROUP=$2; shift 2 ;;
    --gh-org)          GH_ORG=$2;         shift 2 ;;
    --gh-repo)         GH_REPO=$2;        shift 2 ;;
    --gh-env)          GH_ENV=$2;         shift 2 ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

[[ -z "${APP_NAME:-}"       ]] && { echo "Missing --app-name";       usage; }
[[ -z "${RESOURCE_GROUP:-}" ]] && { echo "Missing --resource-group"; usage; }
[[ -z "${GH_ORG:-}"         ]] && { echo "Missing --gh-org";         usage; }
[[ -z "${GH_REPO:-}"        ]] && { echo "Missing --gh-repo";        usage; }
[[ -z "${GH_ENV:-}"         ]] && { echo "Missing --gh-env";         usage; }

# ─── Resolve subscription ─────────────────────────────────────────────────────
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo ""
echo "Subscription  : $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "Resource group: $RESOURCE_GROUP"
echo ""

# ─── App Registration ─────────────────────────────────────────────────────────
echo "▶ Checking app registration..."

EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)

if [[ -n "$EXISTING_APP" ]]; then
  echo "  Already exists, skipping create."
  APP_ID="$EXISTING_APP"
  OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)
else
  SP=$(az ad app create --display-name "$APP_NAME" -o json)
  APP_ID=$(echo "$SP" | jq -r '.appId')
  OBJECT_ID=$(echo "$SP" | jq -r '.id')
  echo "  Created: $APP_ID"
fi

# ─── Service Principal ────────────────────────────────────────────────────────
echo ""
echo "▶ Checking service principal..."

EXISTING_SP=$(az ad sp show --id "$APP_ID" --query id -o tsv 2>/dev/null || true)

if [[ -n "$EXISTING_SP" ]]; then
  echo "  Already exists, skipping create."
  SP_OBJECT_ID="$EXISTING_SP"
else
  az ad sp create --id "$APP_ID" -o none
  SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
  echo "  Created: $SP_OBJECT_ID"
fi

TENANT_ID=$(az account show --query tenantId -o tsv)

echo "  App ID       : $APP_ID"
echo "  Tenant ID    : $TENANT_ID"
echo "  SP Object ID : $SP_OBJECT_ID"

# ─── Federated Identity Credential ───────────────────────────────────────────
echo ""
echo "▶ Checking federated identity credential..."

FED_NAME="${APP_NAME}-federation"
EXISTING_FED=$(az ad app federated-credential list --id "$OBJECT_ID" --query "[?name=='${FED_NAME}'].name" -o tsv 2>/dev/null || true)

if [[ -n "$EXISTING_FED" ]]; then
  echo "  Already exists, skipping create."
else
  az ad app federated-credential create \
    --id "$OBJECT_ID" \
    --parameters "{
      \"name\": \"${FED_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${GH_ORG}/${GH_REPO}:environment:${GH_ENV}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" -o none
  echo "  Created for: ${GH_ORG}/${GH_REPO} @ environment:${GH_ENV}"
fi

# ─── Role Assignments over Resource Group ────────────────────────────────────
echo ""
echo "▶ Checking role assignments..."

RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

for ROLE in "Contributor" "User Access Administrator"; do
  EXISTING_ROLE=$(az role assignment list \
    --assignee "$APP_ID" \
    --role     "$ROLE"   \
    --scope    "$RG_SCOPE" \
    --query    "[0].id" -o tsv 2>/dev/null || true)

  if [[ -n "$EXISTING_ROLE" ]]; then
    echo "  Already assigned, skipping: $ROLE"
  else
    az role assignment create \
      --assignee "$APP_ID" \
      --role     "$ROLE"   \
      --scope    "$RG_SCOPE" -o none
    echo "  ✓ $ROLE"
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════"
echo " Done! Add these to GitHub Actions secrets:"
echo "═══════════════════════════════════════════════"
echo " SP Name               = $APP_NAME"
echo " SP Principal ID       = $SP_OBJECT_ID"
echo " AZURE_CLIENT_ID       = $APP_ID"
echo " AZURE_TENANT_ID       = $TENANT_ID"
echo " AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "═══════════════════════════════════════════════"