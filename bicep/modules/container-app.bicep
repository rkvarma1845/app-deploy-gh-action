// ─── Container App Module ─────────────────────────────────────────────────────
@description('Short application name used as a prefix for all resources.')
param appName string
param location string
param containerAppEnvId string
param uamiId string
param acrLoginServer string
param containerImage string
param appInsightsConnectionString string
param clientUamis array
param clientStorageDetails array
param storageAccountName string

// ─── Per-client Container Apps ────────────────────────────────────────────────
resource clientContainerApps 'Microsoft.App/containerApps@2023-11-02-preview' = [for (uami, i) in clientUamis: {
  name: '${appName}-${uami.client}-container'
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
          name: uami.client
          image: empty(containerImage)
            ? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
            : '${acrLoginServer}/${containerImage}'
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
            // ── UAMI ────────────────────────────────────────────────────────
            {
              name: 'UAMI_CLIENT_ID'
              value: uami.clientId
            }
            {
              name: 'UAMI_PRINCIPAL_ID'
              value: uami.principalId
            }
            // ── Storage ─────────────────────────────────────────────────────
            {
              name: 'STORAGE_ACCOUNT_NAME'
              value: storageAccountName
            }
            {
              name: 'BLOB_CONTAINER_NAME'
              value: clientStorageDetails[i].blobContainerName
            }
            {
              name: 'QUEUE_INBOX'
              value: clientStorageDetails[i].inbox
            }
            {
              name: 'QUEUE_OUTBOX'
              value: clientStorageDetails[i].outbox
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
}]

// ─── Outputs ──────────────────────────────────────────────────────────────────
output clientContainerApps array = [for (uami, i) in clientUamis: {
  client: uami.client
  name:   '${uami.client}-container'
  fqdn:   clientContainerApps[i].properties.configuration.ingress.fqdn
}]
