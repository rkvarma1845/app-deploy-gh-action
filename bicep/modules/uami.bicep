// ─── User Assigned Managed Identity Module ────────────────────────────────────
param identityName string
param location string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

output uamiId string = uami.id
output uamiName string = uami.name
output principalId string = uami.properties.principalId
output clientId string = uami.properties.clientId
