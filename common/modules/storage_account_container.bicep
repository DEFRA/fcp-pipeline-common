param identityName string
param storageName string
param container object

resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageName
}

resource blobServiceResource 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' existing = {
  parent: storageResource
  name: 'default'
}

resource containerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobServiceResource
  name: container.name
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageResource
  ]
}

// Loop over roles
module roleAssignmentModules 'storage_account_container_roleAssignment.bicep' = [
  for role in container.?roles ?? []: {
    params: {
      storageName: storageResource.name
      identityName: identityName
      containerName: container.name
      role: role.name
    }
  }
]
