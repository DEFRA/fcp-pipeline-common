param targetEnvironment string
param subscriptionSpoke string
param altEnvironment string
param topicName string
param role string
param identityClientId string

var topicFullName = toLower('${topicName}-${altEnvironment}')

var roles = {
  sender: 'Azure Service Bus Data Sender'
  receiver: 'Azure Service Bus Data Receiver'
}

output roleCreate string = 'az role assignment create --subscription ${subscription().subscriptionId} --role "${roles[role]}" --assignee ${identityClientId} --scope /subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ServiceBus/namespaces/${targetEnvironment}FFCINFSB${subscriptionSpoke}001/topics/${topicFullName}'
