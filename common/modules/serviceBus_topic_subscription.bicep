param topicName string
param subscription object
param altEnvironment string
param targetEnvironment string
param subscriptionSpoke string

// Creating a symbolic name for an existing resource
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: '${targetEnvironment}FFCINFSB${subscriptionSpoke}001'
}

resource topicResource 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' existing = {
  name: toLower('${topicName}-${altEnvironment}')
  parent: serviceBusNamespace
}
resource subResource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01' = {
  name: toLower(subscription.name)
  parent: topicResource
  properties: {
    autoDeleteOnIdle: subscription.?autoDeleteOnIdle ?? 'P10675199DT2H48M5.4775807S'
    isClientAffine: subscription.?isClientAffine ?? false
    lockDuration: subscription.?lockDuration ?? 'PT1M'
    defaultMessageTimeToLive: subscription.?defaultMessageTimeToLive ?? 'P100D'
    enableBatchedOperations: subscription.?enableBatchedOperations ?? true
    deadLetteringOnMessageExpiration: subscription.?deadLetteringOnMessageExpiration ?? false
    deadLetteringOnFilterEvaluationExceptions: subscription.?deadLetteringOnFilterEvaluationExceptions ?? false
    maxDeliveryCount: subscription.?maxDeliveryCount ?? 10
    requiresSession: subscription.?requiresSession ?? false
  }
}

// Loop over filters
resource ruleResources 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = [for filter in subscription.?filters ?? []: {
  name: filter.name
  parent: subResource
  properties: {
    filterType: filter.?type ?? 'CorrelationFilter'
    correlationFilter: {
      label: filter.?label ?? filter.name
    }
  }
}]
