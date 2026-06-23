// ─── Storage Module ───────────────────────────────────────────────────────────
param location string
param storageAccountName string
param clientNames array
param clientDetails array   // expects output from uami.bicep: [{client, uamiId, principalId, ...}]

// ─── Role Definition IDs ──────────────────────────────────────────────────────
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'

// ─── Storage Account ──────────────────────────────────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// ─── Single Blob Container (shared across all clients) ────────────────────────
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for client in clientNames: {
  parent: blobService
  name: '${client}-blob'
  properties: {
    publicAccess: 'None'
  }
}]

// ─── Queue Service ────────────────────────────────────────────────────────────
resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// ─── Per-client Queues (2 per client: inbox & outbox) ─────────────────────────
resource inboxQueues 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = [for client in clientNames: {
  parent: queueService
  name: '${client}-inbox'
}]

resource outboxQueues 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = [for client in clientNames: {
  parent: queueService
  name: '${client}-outbox'
}]

// ─── Blob Contributor role for each client UAMI ───────────────────────────────
resource blobRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (client, i) in clientDetails: {
  name: guid(storageAccount.id, client.clientPrincipalId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: client.clientPrincipalId
    principalType: 'ServicePrincipal'
  }
}]

// ─── Queue Contributor role for each client UAMI ─────────────────────────────
resource queueRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (client, i) in clientDetails: {
  name: guid(storageAccount.id, client.clientPrincipalId, storageQueueDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalId: client.clientPrincipalId
    principalType: 'ServicePrincipal'
  }
}]

// ─── Outputs ──────────────────────────────────────────────────────────────────
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output clientStorageDetails array = [for (client, i) in clientNames: {
  client: client
  blobContainerName: '${client}-blob'
  inbox:  '${client}-inbox'
  outbox: '${client}-outbox'
}]
