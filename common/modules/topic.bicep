param topic object

param altEnvironment string
param targetEnvironment string
param subscriptionSpoke string
// param identityName string
param identityClientId string

// Creating a symbolic name for an existing resource
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: '${targetEnvironment}FFCINFSB${subscriptionSpoke}001'
}

resource topicResource 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' = {
  name: toLower('${topic.name}-${altEnvironment}')
  parent: serviceBusNamespace
  properties: {
    autoDeleteOnIdle: topic.?autoDeleteOnIdle ?? 'P10675199DT2H48M5.4775807S'
    maxMessageSizeInKilobytes: topic.?maxMessageSizeInKilobytes ?? 256
    defaultMessageTimeToLive: topic.?defaultMessageTimeToLive ?? 'P14D'
    duplicateDetectionHistoryTimeWindow: topic.?duplicateDetectionHistoryTimeWindow ?? 'PT10M'
    enableBatchedOperations: topic.?enableBatchedOperations ?? true
    enableExpress: topic.?enableExpress ?? false
    enablePartitioning: topic.?enablePartitioning ?? false
    supportOrdering: topic.?supportOrdering ?? true
    maxSizeInMegabytes: topic.?maxSizeInMegabytes ?? 5120
  }
}

// Loop over roles
module roleAssignmentModules 'roleAssignmentTopic.bicep' = [
  for role in topic.?roles ?? []: {
    params: {
      altEnvironment: altEnvironment
      identityClientId: identityClientId
      // identityName: identityName
      topicName: topic.name
      role: role.name
      subscriptionSpoke: subscriptionSpoke
      targetEnvironment: targetEnvironment
    }
  }
]



// Loop over subscriptions inside this topic
module subscriptionModules 'subscription.bicep' = [
  for sub in topic.?subscriptions ?? []: {
    params: {
      topicName: topic.name
      subscription: sub
      altEnvironment: altEnvironment
      subscriptionSpoke: subscriptionSpoke
      targetEnvironment: targetEnvironment
    }
  }
]

output roleCreates array = [for i in range(0, length(topic.?roles ?? [])): roleAssignmentModules[i].outputs.roleCreate]
