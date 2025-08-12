param storageName string
param table object
param identityName string

resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageName
}

resource tableServiceResource 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01' existing = {
  parent: storageResource
  name: 'default'
}

resource tableResource 'Microsoft.Storage/storageAccounts/tableServices/tables@2025-01-01' = {
  parent: tableServiceResource
  name: table.name
  properties: {}
  dependsOn: [
    storageResource
  ]
}

// Loop over roles
module roleAssignmentModules 'storage_account_table_roleAssignment.bicep' = [
  for role in table.?roles ?? []: {
    params: {
      storageName: storageResource.name
      identityName: identityName
      tableName: table.name
      role: role.name
    }
  }
]

