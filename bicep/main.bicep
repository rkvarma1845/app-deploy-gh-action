param location string = resourceGroup().location
param environment_name string
param acr_name string

@description('Prefix name to create resources')
param namePrefix string

// Log Analytics Name:
param logAnalyticsWorkspaceName string = toLower('${namePrefix}-loganalytics-${environment_name}')

// App Insights Name:
param applicationInsightsName string = toLower('${namePrefix}-appinsight-${environment_name}')

// Container App Environment Name
param conatainerAppEnvName string = '${namePrefix}-cae-${environment_name}'

// UAMI Name 
param rengineUamiName string = '${namePrefix}-uami-${environment_name}'

// Azure Storage Name
param storage_account_name string =  '${namePrefix}storage${environment_name}'

param DockerImage string

param TenantId string

@description('Location for container app env and container app')
param container_app_env_location string

@description('Client Details')
param clientNames array
param clientIds array
param clientSecrets array
param clientPrincipalIds array

var clientDetails array = [for i in range(0, length(clientNames)): {
  name: toLower(clientNames[i])
  clientId: clientIds[i]
  clientSecret: clientSecrets[i]
  clientPrincipalId: clientPrincipalIds[i]
}]

// Resources
param ContainerAppCpu int
param ContainerAppMemory string
param ContainerAppMinReplicas int
param ContainerAppMaxReplicas int


// ─── 1. User Assigned Managed Identity ───────────────────────────────────────
module uami 'modules/uami.bicep' = {
  name: 'deploy-rengineUami'
  scope: resourceGroup('azure-devops')
  params: {
    rengineUamiName: rengineUamiName
    location: location
  }
}

// ─── 2. Azure Container Registry ─────────────────────────────────────────────
module acr 'modules/acr-role.bicep' = {
  name: 'deploy-acr-roll'
  params: {
    acrName: acr_name
    uamiPrincipalId: uami.outputs.uamiPrincipalId
  }
}

// ─── 3. Log Analytics Workspace ──────────────────────────────────────────────
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

// ─── 4. Application Insights ─────────────────────────────────────────────────
module appInsights 'modules/app-insights.bicep' = {
  name: 'deploy-app-insights'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// ─── 4. Azure Storage ─────────────────────────────────────────────────
module AzureStorage 'modules/storage.bicep' = {
  name: 'deploy-azure-storage'
  dependsOn: [
    appInsights
  ]
  params: {
    storage_account_name: storage_account_name
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    clientNames: clientNames
    clientDetails: clientDetails
    uamiPrincipalId: uami.outputs.uamiPrincipalId
    namePrefix: namePrefix
    environment_name: environment_name
  }
}

// ─── 5. Container Apps Environment ───────────────────────────────────────────
module ContainerEnv 'modules/container-env.bicep' = {
  name: 'deploy-container-env'
  params: {
    conatainerAppEnvName: conatainerAppEnvName
    location: container_app_env_location
    logAnalyticsWorkspaceCustomerId: logAnalytics.outputs.customerId
    logAnalyticsWorkspaceSharedKey: logAnalytics.outputs.primarySharedKey
  }
}

// ─── 6. Container App ─────────────────────────────────────────────────────────
module ContainerApp 'modules/container-app.bicep' = {
  name: 'deploy-container-app'
  params: {
    location: container_app_env_location
    environment_name: environment_name
    namePrefix: namePrefix
    DockerImage: DockerImage
    storage_account_name: storage_account_name
    TenantId: TenantId
    containerAppEnvironmentId: ContainerEnv.outputs.envId
    AppInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    acrLoginServer: acr.outputs.loginServer
    clientDetails: clientDetails
    uamiId: uami.outputs.uamiId
    ContainerAppCpu: ContainerAppCpu
    ContainerAppMemory: ContainerAppMemory
    ContainerAppMinReplicas: ContainerAppMinReplicas
    ContainerAppMaxReplicas: ContainerAppMaxReplicas
  }
}
