# Node.js App – Azure Container Apps via GitHub Actions (OIDC)

A production-ready CI/CD pipeline that deploys a Node.js containerised application to **Azure Container Apps** using:

- **OIDC** authentication (no long-lived client secrets stored in GitHub)
- **Modular Bicep** – one file per Azure resource
- **Change detection** – infrastructure and app are deployed independently, only when their files change
- **Log Analytics + Application Insights** – full observability out of the box

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
│
├── bicep/
│   ├── main.bicep              # Orchestrator – wires all modules
│   └── modules/
│       ├── uami.bicep          # User Assigned Managed Identity
│       ├── acr.bicep           # Azure Container Registry + AcrPull role
│       ├── log-analytics.bicep # Log Analytics Workspace
│       ├── app-insights.bicep  # Application Insights (linked to Log Analytics)
│       ├── container-env.bicep # Container Apps Environment
│       └── container-app.bicep # Container App
│
├── scripts/
│   ├── setup-oidc.sh           # One-time: creates App Registration + OIDC federation
│   └── create-uami.sh          # Idempotent: ensures UAMI exists before Bicep runs
│
├── index.js                    # Express app
├── Dockerfile
├── docker-compose.yml
└── package.json
```

---

## One-Time Setup

### 1. Run `setup-oidc.sh`

This script creates an **Azure AD App Registration** (no password/secret), configures three **Federated Identity Credentials** for GitHub Actions OIDC, and grants the resulting **Service Principal** the two roles it needs over your Resource Group:

| Role | Why |
|------|-----|
| `Contributor` | Deploy and manage all ARM resources |
| `User Access Administrator` | Assign AcrPull role to the UAMI inside Bicep |

```bash
chmod +x scripts/setup-oidc.sh

./scripts/setup-oidc.sh \
  --subscription  <AZURE_SUBSCRIPTION_ID>  \
  --resource-group nodejs-app-rg           \
  --gh-org        <YOUR_GITHUB_USERNAME_OR_ORG> \
  --gh-repo       <YOUR_REPO_NAME>
```

The script prints three values at the end. Add them as **GitHub repository secrets**:

| Secret Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | App Registration (client) ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |

> **Settings → Secrets and variables → Actions → New repository secret**

No `AZURE_CREDENTIALS` JSON blob is needed — OIDC tokens are issued per-run.

---

### 2. (Optional) Adjust `env:` in the workflow

Open `.github/workflows/deploy.yml` and update the top-level `env:` block if your names differ:

```yaml
env:
  APP_NAME: nodejs-app          # prefix for all resource names
  ACR_NAME: nodejsappacr        # must be globally unique, alphanumeric only
  RESOURCE_GROUP: nodejs-app-rg
  IDENTITY_NAME: nodejs-uami
  LOCATION: centralindia
```

---

## How the Pipeline Works

```
push / PR / workflow_dispatch
        │
        ▼
┌─────────────────────┐
│   detect-changes    │  Uses dorny/paths-filter to diff the commit
└────────┬────────────┘
         │
    ┌────┴────────────────────────────┐
    │                                 │
    ▼ (bicep/** changed)              ▼ (app code changed)
┌──────────────┐              ┌──────────────────────┐
│infrastructure│              │     deploy-app        │
│              │              │                       │
│ create-uami  │              │  docker build & push  │
│ bicep deploy │              │  az containerapp      │
│  (modular)   │              │       update          │
└──────────────┘              └──────────────────────┘
```

- **Infrastructure** job runs only when `bicep/**` files change (or `force_infra=true`).
- **App** job runs only when `index.js`, `package.json`, `Dockerfile` etc. change (or `force_app=true`).
- Both jobs can run in the same push if both areas changed.
- If nothing changed, the **no-changes** job logs an informational message.

### Manual Override

Go to **Actions → Build & Deploy → Run workflow** and toggle:
- `force_infra` – re-deploys Bicep even if no Bicep files changed
- `force_app` – rebuilds and re-pushes the Docker image even if no code changed

---

## Azure Resources Deployed

| Resource | Name pattern | Module |
|---|---|---|
| User Assigned Identity | `nodejs-uami` | `uami.bicep` |
| Container Registry | `nodejsappacr` | `acr.bicep` |
| Log Analytics Workspace | `nodejs-app-logs` | `log-analytics.bicep` |
| Application Insights | `nodejs-app-appinsights` | `app-insights.bicep` |
| Container Apps Environment | `nodejs-app-env` | `container-env.bicep` |
| Container App | `nodejs-app-container` | `container-app.bicep` |

---

## Local Development

```bash
# Run with Docker Compose
docker compose up --build

# App: http://localhost:8080
# Health: http://localhost:8080/health
```

---

## Application Endpoints

| Path | Description |
|---|---|
| `GET /` | Hello message + version |
| `GET /health` | Uptime, hostname, environment |
