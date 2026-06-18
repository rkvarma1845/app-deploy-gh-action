// ─── Main Bicep Orchestrator ──────────────────────────────────────────────────
// Wires together: UAMI → ACR → Log Analytics → App Insights
//                 → Container App Environment → Container App

@description('Short application name used as a prefix for all resources.')
param appName string = 'nodejs-app'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the Azure Container Registry (must be globally unique, alphanumeric).')
param acrName string

@description('Name of the User Assigned Managed Identity.')
param userAssignedIdentityName string

@description('Docker image tag to deploy. Leave empty on first infrastructure deploy.')
param containerImage string = ''

@description('')
param clientNames array

@description('')
param storageAccountName string = 'enginestoragedev'

// ─── 1. User Assigned Managed Identity ───────────────────────────────────────
module uami 'modules/uami.bicep' = {
  name: 'deploy-uami'
  params: {
    identityName: userAssignedIdentityName
    location: location
    clientNames: clientNames
  }
}

// ─── 2. Azure Container Registry ─────────────────────────────────────────────
module acr 'modules/acr-role.bicep' = {
  name: 'deploy-acr'
  params: {
    acrName: acrName
    uamiPrincipalId: uami.outputs.principalId
  }
}

// ─── 3. Log Analytics Workspace ──────────────────────────────────────────────
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    appName: appName
    location: location
  }
}

// ─── 4. Application Insights ─────────────────────────────────────────────────
module appInsights 'modules/app-insights.bicep' = {
  name: 'deploy-app-insights'
  params: {
    appName: appName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// ─── 4. Azure Storage ─────────────────────────────────────────────────
module azureStorage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageAccountName: storageAccountName
    clientNames: clientNames
    clientUamis: uami.outputs.clientUamiDetails  // from uami.bicep output
  }
}

// ─── 5. Container Apps Environment ───────────────────────────────────────────
module containerEnv 'modules/container-env.bicep' = {
  name: 'deploy-container-env'
  params: {
    appName: appName
    location: location
    logAnalyticsCustomerId: logAnalytics.outputs.customerId
    logAnalyticsPrimaryKey: logAnalytics.outputs.primarySharedKey
  }
}

// ─── 6. Container App ─────────────────────────────────────────────────────────
module containerApp 'modules/container-app.bicep' = {
  name: 'deploy-container-app'
  params: {
    appName: appName
    location: location
    containerAppEnvId: containerEnv.outputs.envId
    uamiId: uami.outputs.uamiId
    acrLoginServer: acr.outputs.loginServer
    containerImage: containerImage
    appInsightsConnectionString: appInsights.outputs.connectionString
    clientUamis: uami.outputs.clientUamiDetails
    clientStorageDetails: azureStorage.outputs.clientStorageDetails
    storageAccountName: storageAccountName
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────
output acrLoginServer string = acr.outputs.loginServer
output clientContainerApps array = containerApp.outputs.clientContainerApps
output appInsightsName string = appInsights.outputs.appInsightsName
output logAnalyticsName string = logAnalytics.outputs.workspaceName
