// ─── User Assigned Managed Identity Module ────────────────────────────────────
param rengineUamiName string
param location string

resource clientUami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: rengineUamiName
  location: location
}

output uamiId string = clientUami.id
output uamiPrincipalId string = clientUami.properties.principalId
