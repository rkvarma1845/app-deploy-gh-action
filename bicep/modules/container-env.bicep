// ─── Container Apps Environment Module ───────────────────────────────────────
param appName string
param location string
param logAnalyticsCustomerId string
param logAnalyticsPrimaryKey string

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: '${appName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsPrimaryKey
      }
    }
  }
}

output envId string = containerAppEnv.id
output envName string = containerAppEnv.name
