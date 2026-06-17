#!/bin/bash
# =============================================================================
# setup-oidc.sh
#
# PURPOSE
#   Creates (or reuses) an Azure AD App Registration + Service Principal,
#   adds three Federated Identity Credentials for GitHub Actions OIDC
#   (main branch, PRs, and manual dispatch), and assigns the Service
#   Principal the roles it needs over the target Resource Group:
#     • Contributor          – deploy / manage all ARM resources
#     • User Access Administrator – assign roles (e.g. AcrPull to UAMI)
#
# USAGE
#   ./scripts/setup-oidc.sh \
#     --subscription  <AZURE_SUBSCRIPTION_ID>  \
#     --resource-group <RESOURCE_GROUP_NAME>   \
#     --gh-org         <GITHUB_ORG_OR_USER>    \
#     --gh-repo        <GITHUB_REPO_NAME>      \
#     [--app-name      <APP_REGISTRATION_NAME>]
#
# PREREQUISITES
#   • Azure CLI logged in as an Owner / User Access Administrator on the
#     subscription (needed to create role assignments).
#   • jq installed (standard on GitHub-hosted runners).
#
# OUTPUTS
#   Prints the three GitHub Actions secrets you need to set:
#     AZURE_CLIENT_ID
#     AZURE_TENANT_ID
#     AZURE_SUBSCRIPTION_ID
# =============================================================================

set -euo pipefail

# ─── Helpers ──────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | cut -c3-
  exit 1
}

log()  { echo "[$(date -u '+%H:%M:%S')] $*"; }
warn() { echo "[$(date -u '+%H:%M:%S')] ⚠️  $*" >&2; }
die()  { echo "[$(date -u '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

# ─── Defaults ─────────────────────────────────────────────────────────────────
APP_REG_NAME=""
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
GH_ORG=""
GH_REPO=""

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription)   SUBSCRIPTION_ID="$2";  shift 2 ;;
    --resource-group) RESOURCE_GROUP="$2";   shift 2 ;;
    --gh-org)         GH_ORG="$2";           shift 2 ;;
    --gh-repo)        GH_REPO="$2";          shift 2 ;;
    --app-name)       APP_REG_NAME="$2";     shift 2 ;;
    -h|--help)        usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# ─── Validate required args ───────────────────────────────────────────────────
[[ -z "$SUBSCRIPTION_ID" ]]  && die "--subscription is required"
[[ -z "$RESOURCE_GROUP" ]]   && die "--resource-group is required"
[[ -z "$GH_ORG" ]]           && die "--gh-org is required"
[[ -z "$GH_REPO" ]]          && die "--gh-repo is required"

# Default app registration name
[[ -z "$APP_REG_NAME" ]] && APP_REG_NAME="${GH_REPO}-github-actions"

# ─── Verify Azure CLI is authenticated ────────────────────────────────────────
log "Verifying Azure CLI authentication..."
CURRENT_USER=$(az account show --query user.name -o tsv 2>/dev/null) \
  || die "Not logged in. Run: az login"
log "Authenticated as: $CURRENT_USER"

az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)
log "Subscription : $SUBSCRIPTION_ID"
log "Tenant       : $TENANT_ID"

# ─── Ensure Resource Group exists ─────────────────────────────────────────────
log "Checking Resource Group '$RESOURCE_GROUP'..."
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
  warn "Resource Group '$RESOURCE_GROUP' not found."
  warn "Create it first, or re-run after 'az group create'."
  die "Aborting – Resource Group must exist before role assignments can be made."
fi
RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)
log "Resource Group ID: $RG_ID"

# ─── Create (or reuse) App Registration ──────────────────────────────────────
log "Looking up App Registration '$APP_REG_NAME'..."
APP_ID=$(az ad app list \
  --display-name "$APP_REG_NAME" \
  --query "[0].appId" -o tsv 2>/dev/null || true)

if [[ -z "$APP_ID" || "$APP_ID" == "null" ]]; then
  log "Creating App Registration '$APP_REG_NAME'..."
  APP_ID=$(az ad app create \
    --display-name "$APP_REG_NAME" \
    --query appId -o tsv)
  log "Created App Registration. Client ID: $APP_ID"
else
  log "Reusing existing App Registration. Client ID: $APP_ID"
fi

# ─── Create (or reuse) Service Principal ──────────────────────────────────────
log "Checking Service Principal for App '$APP_ID'..."
SP_OID=$(az ad sp list \
  --filter "appId eq '$APP_ID'" \
  --query "[0].id" -o tsv 2>/dev/null || true)

if [[ -z "$SP_OID" || "$SP_OID" == "null" ]]; then
  log "Creating Service Principal..."
  SP_OID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
  log "Service Principal Object ID: $SP_OID"
  # Brief pause – AAD replication lag
  sleep 15
else
  log "Reusing existing Service Principal. OID: $SP_OID"
fi

# ─── Helper: add federated credential (idempotent) ───────────────────────────
add_federated_credential() {
  local NAME="$1"
  local SUBJECT="$2"
  local DESCRIPTION="$3"

  # Check if it already exists
  EXISTING=$(az ad app federated-credential list \
    --id "$APP_ID" \
    --query "[?name=='${NAME}'].name" -o tsv 2>/dev/null || true)

  if [[ -n "$EXISTING" ]]; then
    log "  Federated credential '$NAME' already exists – skipping."
    return
  fi

  log "  Adding federated credential '$NAME' (subject: $SUBJECT)..."
  az ad app federated-credential create \
    --id "$APP_ID" \
    --parameters "{
      \"name\": \"${NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"${SUBJECT}\",
      \"description\": \"${DESCRIPTION}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" \
    --output none
  log "  ✅ Created."
}

# ─── Federated Identity Credentials ──────────────────────────────────────────
log "Configuring Federated Identity Credentials..."
REPO_PATH="${GH_ORG}/${GH_REPO}"

add_federated_credential \
  "github-main" \
  "repo:${REPO_PATH}:ref:refs/heads/main" \
  "GitHub Actions – main branch pushes"

add_federated_credential \
  "github-pull-request" \
  "repo:${REPO_PATH}:pull_request" \
  "GitHub Actions – pull requests"

add_federated_credential \
  "github-workflow-dispatch" \
  "repo:${REPO_PATH}:ref:refs/heads/main" \
  "GitHub Actions – workflow_dispatch on main"

# ─── Helper: assign role (idempotent) ────────────────────────────────────────
assign_role() {
  local ROLE="$1"
  local SCOPE="$2"

  EXISTING=$(az role assignment list \
    --assignee "$SP_OID" \
    --role "$ROLE" \
    --scope "$SCOPE" \
    --query "[0].id" -o tsv 2>/dev/null || true)

  if [[ -n "$EXISTING" && "$EXISTING" != "null" ]]; then
    log "  Role '$ROLE' already assigned – skipping."
    return
  fi

  log "  Assigning role '$ROLE' on scope: $SCOPE ..."
  az role assignment create \
    --assignee-object-id "$SP_OID" \
    --assignee-principal-type ServicePrincipal \
    --role "$ROLE" \
    --scope "$SCOPE" \
    --output none
  log "  ✅ Assigned."
}

# ─── Role Assignments on the Resource Group ──────────────────────────────────
log "Assigning RBAC roles on Resource Group '$RESOURCE_GROUP'..."

# Contributor – lets the SP deploy all ARM resources
assign_role "Contributor" "$RG_ID"

# User Access Administrator – lets the SP do role assignments
# (e.g. granting AcrPull to the UAMI inside the Bicep template)
assign_role "User Access Administrator" "$RG_ID"

# ─── Print GitHub Secrets ────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║            GitHub Actions Secrets – add these to your repo          ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  %-22s  %-44s  ║\n" "Secret Name"       "Value"
printf "║  %-22s  %-44s  ║\n" "──────────────────────" "────────────────────────────────────────────"
printf "║  %-22s  %-44s  ║\n" "AZURE_CLIENT_ID"       "$APP_ID"
printf "║  %-22s  %-44s  ║\n" "AZURE_TENANT_ID"       "$TENANT_ID"
printf "║  %-22s  %-44s  ║\n" "AZURE_SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "In your GitHub repo: Settings → Secrets and variables → Actions → New repository secret"
echo ""
log "✅ OIDC setup complete."
