param storage_account_name string
param logAnalyticsWorkspaceId string
param clientNames array
param clientDetails array
param uamiPrincipalId string
param namePrefix string
param environment_name string

// Stroage account 
resource storageAccount 'Microsoft.Storage/storageAccounts@2026-04-01' = {
  name: storage_account_name
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dualStackEndpointPreference: {
      publishIpv6Endpoint: false
    }
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: false
    networkAcls: {
      ipv6Rules: []
      resourceAccessRules: [
        {
          tenantId: '1610ea52-a4e2-41bc-bd18-39e15f1ad63b'
          resourceId: '/subscriptions/0e72310f-1fed-4144-804a-250579cfd2ea/providers/Microsoft.Security/datascanners/StorageDataScanner'
        }
      ]
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// New Blob Container 
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2026-04-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    staticWebsite: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
  }
}

resource diagnosticsBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobServices
  name: blobServices.name
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageWrite'
        enabled: true
      }
    ]
  }
}


resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = [for client in clientNames: {
  parent: blobServices
  name: toLower('${namePrefix}-${client}-${environment_name}')
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}]


// New Queue 
resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource diagnosticsQueue 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: queueServices
  name: queueServices.name
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageWrite'
        enabled: true
      }
    ]
  }
}

resource storageQueues_transactional 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = [for client in clientNames: {
  parent: queueServices
  name: toLower('${namePrefix}-transactional-${client}-${environment_name}')
  properties: {
    metadata: {}
  }
}]

resource storageQueues_batch_processing 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = [for client in clientNames: {
  parent: queueServices
  name: toLower('${namePrefix}-batch-processing-${client}-${environment_name}')
  properties: {
    metadata: {}
  }
}]


// Storage Blob Data Contributor - Storage Container
resource roleAssignmentsBlobContributorProfiler 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (client, index) in clientDetails: {
  name: guid(blobContainers[index].id, 'BlobContributor', client.name,client.clientPrincipalId)
  scope: blobContainers[index]
  properties: {
    principalId: client.clientPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
  }
  dependsOn:[
    blobContainers[index]
  ]
}]

// Storage Queue Data Contributor - Storage Queue
resource roleAssignmentsQueueContributorTransactional 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (client, index) in clientDetails: {
  name: guid(storageQueues_transactional[index].id, 'QueueContributor', client.name,client.clientPrincipalId)
  scope: storageQueues_transactional[index]
  properties: {
    principalId: client.clientPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalType: 'ServicePrincipal'
  }
    dependsOn:[
    storageQueues_transactional[index]
  ]
}]

// Storage Queue Data Contributor - Storage Queue
resource roleAssignmentsQueueContributorBatchProcessing 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (client, index) in clientDetails: {
  name: guid(storageQueues_batch_processing[index].id, 'QueueContributor', client.name,client.clientPrincipalId)
  scope: storageQueues_batch_processing[index]
  properties: {
    principalId: client.clientPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalType: 'ServicePrincipal'
  }
    dependsOn:[
    storageQueues_batch_processing[index]
  ]
}]


// Storage Queue Data Reader
resource queueReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, 'QueueReader', uamiPrincipalId)
  scope: storageAccount
  properties: {
    principalId: uamiPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '19e7f393-937e-4f77-808e-94535e297925') // Storage Queue Data Reader
    principalType: 'ServicePrincipal'
  }
}


output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output storageAccountId string = storageAccount.id
output clientStorageDetails array= [for client in clientNames: {
  client: client
  blobContainerName: client
  transactionalQueue: toLower('transactional-${client}')
  batchProcessingQueue: toLower('batch-processing-${client}')
}]
