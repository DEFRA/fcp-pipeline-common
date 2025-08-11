param storageName string
param identityName string
param tableName string
param role string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: identityName
}

resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageName
}

resource tableServiceResource 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01'  existing = {
  parent: storageResource
  name: 'default'
}

resource tableResource 'Microsoft.Storage/storageAccounts/tableServices/tables@2025-01-01' existing = {
  parent: tableServiceResource
  name: tableName
}

var roles = {
  tableContributor: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  )
}

resource senderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: tableResource
  name: guid('${tableResource.id}${identityName}${roles[role]}')
  properties: {
    principalId: identity.properties.principalId
    roleDefinitionId: roles[role]
    principalType: 'ServicePrincipal'
  }
}
