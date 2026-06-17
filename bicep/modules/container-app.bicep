// ─── Container App Module ─────────────────────────────────────────────────────
param appName string
param location string
param containerAppEnvId string
param uamiId string
param acrLoginServer string
param imageTag string
param appInsightsConnectionString string

resource containerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: '${appName}-container'
  location: location

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }

  properties: {
    managedEnvironmentId: containerAppEnvId

    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }

      registries: [
        {
          server: acrLoginServer
          identity: uamiId
        }
      ]
    }

    template: {
      containers: [
        {
          name: appName
          // Use placeholder on first deploy; updated by workflow on each push
          image: empty(imageTag)
            ? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
            : '${acrLoginServer}/${appName}:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'PORT'
              value: '8080'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
        }
      ]

      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output containerAppName string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
