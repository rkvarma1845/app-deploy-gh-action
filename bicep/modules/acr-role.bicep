// ─── Azure Container Registry Module ──────────────────────────────────────────
param acrName string
// param location string
param clientUamis array

// ─── ACR Resource ─────────────────────────────────────────────────────────────
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// ─── Grant UAMI AcrPull role on ACR ───────────────────────────────────────────
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (uami, i) in clientUamis: {
  name: guid(acr.id, uami.principalId, 'acrpull')
  scope: acr
  properties: {
    principalId: uami.principalId
    // AcrPull built-in role ID
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalType: 'ServicePrincipal'
  }
}]

output acrId string = acr.id
output acrName string = acr.name
output loginServer string = acr.properties.loginServer
