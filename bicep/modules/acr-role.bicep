// ─── Azure Container Registry Module ──────────────────────────────────────────
param acrName string
// param location string
param uamiPrincipalId string

// ─── ACR Resource ─────────────────────────────────────────────────────────────
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// ─── Grant UAMI AcrPull role on ACR ───────────────────────────────────────────
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, uamiPrincipalId, 'acrpull')
  scope: acr
  properties: {
    principalId: uamiPrincipalId
    // AcrPull built-in role ID
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalType: 'ServicePrincipal'
  }
}

output loginServer string = acr.properties.loginServer
