param storageName string
param identityName string
param queueName string
param role string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: identityName
}

resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageName
}

resource queueServiceResource 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' existing = {
  parent: storageResource
  name: 'default'
}

resource queueResource 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' existing = {
  parent: queueServiceResource
  name: queueName
}

var roles = {
  queueTriggerReader: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '19e7f393-937e-4f77-808e-94535e297925'
  )
  queueTriggerProcessor: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '8a0f0c08-91a1-4084-bc3d-661d67233fed'
  )
  queueSender: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
  )
}

resource senderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: queueResource
  name: guid('${queueResource.id}${identityName}${roles[role]}')
  properties: {
    principalId: identity.properties.principalId
    roleDefinitionId: roles[role]
    principalType: 'ServicePrincipal'
  }
}
