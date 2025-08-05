param queue object

param altEnvironment string
param targetEnvironment string
param subscriptionSpoke string
// param identityName string
param identityClientId string

// Creating a symbolic name for an existing resource
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: '${targetEnvironment}FFCINFSB${subscriptionSpoke}001'
}

resource queuesResources 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  name: toLower('${queue.name}-${altEnvironment}')
  parent: serviceBusNamespace
  properties: {
    autoDeleteOnIdle: queue.?autoDeleteOnIdle ?? 'P10675198DT2H48M5.477S'
    deadLetteringOnMessageExpiration: queue.?deadLetteringOnMessageExpiration ?? false
    maxMessageSizeInKilobytes: queue.?maxMessageSizeInKilobytes ?? 256
    lockDuration: queue.?lockDuration ?? 'PT30S'
    maxSizeInMegabytes: queue.?maxSize ?? 5120
    requiresDuplicateDetection: queue.?requiresDuplicateDetection ?? false
    duplicateDetectionHistoryTimeWindow: queue.?duplicateDetectionHistoryTimeWindow ?? 'PT10M'
    defaultMessageTimeToLive: queue.?defaultMessageTimeToLive ?? 'P14D'
    requiresSession: queue.?requiresSession ?? false
    enablePartitioning: queue.?enablePartitioning ?? false
  }
}

// Loop over roles
module roleAssignmentModules 'roleAssignmentQueue.bicep' = [
  for role in queue.?roles ?? []: {
    params: {
      altEnvironment: altEnvironment
      identityClientId: identityClientId
      // identityName: identityName
      queueName: queue.name
      role: role.name
      subscriptionSpoke: subscriptionSpoke
      targetEnvironment: targetEnvironment
    }
  }
]

output roleCreates array = [for i in range(0, length(queue.?roles ?? [])): roleAssignmentModules[i].outputs.roleCreate]
