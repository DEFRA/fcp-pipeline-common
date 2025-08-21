# FCP Pipeline Common

## Variables

The `variables.yaml` file provides reusable variables across all pipeline stages:

### Usage

[Documentation](https://eaflood.atlassian.net/wiki/spaces/FAPT/pages/5835522141/FFC+FCP+Service+Deployment+with+ADO+Pipeline)

Include the variables template in any stage:

```yaml
variables:
  - template: variables.yaml
```

```yaml
# Use in conditional logic
- ${{ if eq(variables['isPr'], true) }}:
    - script: echo "Building PR #$(prNumber)"

# Use in bash scripts
- script: |
    if [ "$(isPr)" = "True" ]; then
      DOCKER_TAG="myapp:pr-$(prNumber)"
    else
      DOCKER_TAG="myapp:$(releaseVersion)"
    fi
```

## Provisining file `provision.azure.yaml`

```yaml
resources:
  identity: identity-name
  service_bus:
    queues:
      - name: queue-name
        roles:
          - name: sender
          - name: receiver
    topics:
      - name: topic-name
        roles:
          - name: sender
          - name: receiver
        subscriptions:
          - name: topic-subscriptions-name
  storage_accounts:
    - name: storage-name
      containers:
        - name: container-name
          roles:
            - name: blobContributor
      tables:
        - name: tableName
          roles:
            - name: tableContributor
      queues:
        - name: queue-name
          roles:
            - name: queueTriggerReader
            - name: queueTriggerProcessor
            - name: queueSender
      roles:
        - name: storageAccountContributor
```
