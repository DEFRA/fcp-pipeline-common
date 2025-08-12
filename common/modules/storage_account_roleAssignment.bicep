// param targetEnvironment string
// param subscriptionSpoke string

param storageName string
param identityName string
param role string

// Creating a symbolic name for an existing resource
// resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
//   name: storageName
// }

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: identityName
}

var roles = {
  storageAccountContributor: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  )
  readerAndDataAccess: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'c12c1c16-33a1-487b-954d-41c89c60f349'
  )
}


resource senderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('Microsoft.Storage/storageAccounts${storageName}${identityName}${roles[role]}')
  // scope: topicResource
  properties: {
    principalId: identity.properties.principalId
    roleDefinitionId: roles[role]
    principalType: 'ServicePrincipal'
  }
}
