// ─── Container Apps Environment Module ───────────────────────────────────────
param conatainerAppEnvName string
param location string
param logAnalyticsWorkspaceCustomerId string
@secure()
param logAnalyticsWorkspaceSharedKey string

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: conatainerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceCustomerId
        sharedKey: logAnalyticsWorkspaceSharedKey
      }
    }
  }
}

output envId string = containerAppEnv.id
output envName string = containerAppEnv.name
