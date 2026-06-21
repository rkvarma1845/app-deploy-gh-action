// ─── User Assigned Managed Identity Module ────────────────────────────────────
param location string
param clientNames array = []

resource clientUamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [for client in clientNames: {
  name: '${client}-uami'
  location: location
}]

output clientUamiDetails array = [for (client, i) in clientNames: {
  client: client
  uamiId: clientUamis[i].id
  uamiName: clientUamis[i].name
  principalId: clientUamis[i].properties.principalId
  clientId: clientUamis[i].properties.clientId
}]
