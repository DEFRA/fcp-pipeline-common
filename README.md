# FCP Pipeline Common

## Variables

The `variables.yaml` file provides reusable variables across all pipeline stages:

### Usage

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
