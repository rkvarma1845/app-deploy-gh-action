// ─── User Assigned Managed Identity Module ────────────────────────────────────
param identityName string
param location string
param clientNames array = []

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource clientUamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [for client in clientNames: {
  name: '${client}-uami'
  location: location
}]

output uamiId string = uami.id
output uamiName string = uami.name
output principalId string = uami.properties.principalId
output clientId string = uami.properties.clientId

output clientUamiDetails array = [for (client, i) in clientNames: {
  client: client
  uamiId: clientUamis[i].id
  uamiName: clientUamis[i].name
  principalId: clientUamis[i].properties.principalId
  clientId: clientUamis[i].properties.clientId
}]
