param storageName string
param queue object
param identityName string

resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageName
}

resource queueServiceResource 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' existing = {
  parent: storageResource
  name: 'default'
}

resource queueResource 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = {
  parent: queueServiceResource
  name: queue.name
  properties: {
    metadata: {}
  }
  dependsOn: [
    storageResource
  ]
}

// Loop over roles
module roleAssignmentModules 'storage_account_queue_roleAssignment.bicep' = [
  for role in queue.?roles ?? []: {
    params: {
      storageName: storageResource.name
      identityName: identityName
      queueName: queue.name
      role: role.name
    }
  }
]
