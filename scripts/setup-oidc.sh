#!/bin/bash
# Usage:
  # ./scripts/setup-oidc.sh \
  # --app-id  1e230fe1-1410-4ccb-8898-eb6de2b7286c \
  # --gh-org  rkvarma1845 \
  # --gh-repo app-deploy-gh-action \
  # --env     main

set -euo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id)  APP_ID="$2";  shift 2 ;;
    --gh-org)  GH_ORG="$2";  shift 2 ;;
    --gh-repo) GH_REPO="$2"; shift 2 ;;
    --env)     ENV="$2";     shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"${GH_REPO}-${ENV}-environment\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${GH_ORG}/${GH_REPO}:environment:${ENV}\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}" --output none

echo "✅ Federated credential created for environment: ${ENV}"
