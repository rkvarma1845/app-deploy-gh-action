param location string
param environment_name string

// Resource names prefix
param namePrefix string

// Image parameters:
param DockerImage string

param storage_account_name string
// Genreal Variables
param TenantId string

param containerAppEnvironmentId string
param AppInsightsInstrumentationKey string

param acrLoginServer string
param clientDetails array
param uamiId string

// Resources
param ContainerAppCpu int
param ContainerAppMemory string
param ContainerAppMinReplicas int
param ContainerAppMaxReplicas int

resource ContainerApp 'Microsoft.App/containerApps@2024-03-01' = [
  for (client, index) in clientDetails: {
    name: take(toLower('${namePrefix}-${client.name}-${environment_name}'), 32)
    location: location
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: { '${uamiId}': {} }
    }
    properties: {
      environmentId: containerAppEnvironmentId
      workloadProfileName: 'Consumption'
      configuration: {
        activeRevisionsMode: 'Single'
        ingress: {
          external: true
          transport: 'auto'
          allowInsecure: false
          targetPort: 8080
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
            env: [
              {
                name: 'environment_name'
                value: environment_name
              }
              // QueueProcessing
              {
                name: 'AppSettings__QueueProcessing__QueueName'
                value: toLower('${namePrefix}-batch-processing-${client.name}-${environment_name}')
              }
              // AzureQueueDetails
              {
                name: 'AppSettings__AzureBlobDetails__AccountName'
                value: storage_account_name
              }
              {
                name: 'AppSettings__AzureBlobDetails__ClientId'
                value: client.clientId
              }
              {
                name: 'AppSettings__AzureBlobDetails__ClientSecret'
                value: client.clientSecret
              }
              {
                name: 'AppSettings__AzureBlobDetails__TenantId'
                value: TenantId
              }
              // Azure Blob Storage
              {
                name: 'AppSettings__AzureBlobStorage__ContainerName'
                value: toLower('${namePrefix}-${client}-${environment_name}')
              }
              {
                name: 'AppInsightsInstrumentationKey'
                value: AppInsightsInstrumentationKey
              }
            ]
            image: '${acrLoginServer}/${DockerImage}'
            name: namePrefix
            resources: {
              cpu: ContainerAppCpu
              memory: ContainerAppMemory
            }
          }
        ]
        scale: {
          minReplicas: ContainerAppMinReplicas
          maxReplicas: ContainerAppMaxReplicas
          rules: [
            // Rule 1 - scale on batch-processing queue
            {
              name: 'batch-processing-queue-depth'
              custom: {
                type: 'azure-queue'
                metadata: {
                  queueName: toLower('${namePrefix}-batch-processing-${client.name}-${environment_name}')
                  accountName: storage_account_name
                  queueLength: '1' // one message → one replica
                  cloud: 'AzurePublicCloud'
                }
                // KEDA reads the queue using the workload identity in workloadIdentity=
                // mode. Container Apps maps this to the per-client UAMI bound to
                // the app (which has Queue Data Contributor on its own queue).
                identity: uamiId
              }
            }

            // Rule 2 - scale on transactional queue
            {
              name: 'transactional-queue-depth'
              custom: {
                type: 'azure-queue'
                metadata: {
                  queueName: toLower('${namePrefix}-transactional-${client.name}-${environment_name}')
                  accountName: storage_account_name
                  queueLength: '1' // one message → one replica
                  cloud: 'AzurePublicCloud'
                }
                // KEDA reads the queue using the workload identity in workloadIdentity=
                // mode. Container Apps maps this to the per-client UAMI bound to
                // the app (which has Queue Data Contributor on its own queue).
                identity: uamiId
              }
            }
          ]
        }
      }
    }
  }
]

output clientContainerApps array = [
  for (client, i) in clientDetails: {
    client: client.name
    name: toLower('${namePrefix}-${client.name}-${environment_name}')
    fqdn: ContainerApp[i].properties.configuration.ingress.fqdn
  }
]
