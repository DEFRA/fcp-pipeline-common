param storageName string
param identityName string
param containerName string
param role string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: identityName
}

resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageName
}

resource blobServiceResource 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' existing = {
  parent: storageResource
  name: 'default'
}

resource containerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' existing = {
  parent: blobServiceResource
  name: containerName
}

var roles = {
  blobContributor: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  )
}

resource senderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerResource
  name: guid('${containerResource.id}${identityName}${roles[role]}')
  properties: {
    principalId: identity.properties.principalId
    roleDefinitionId: roles[role]
    principalType: 'ServicePrincipal'
  }
}
