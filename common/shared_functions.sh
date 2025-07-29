#!/usr/bin/bash
# Common shared functions for the FCP pipeline

# fuction to create a smal unique string from a given input
readable_hash_id() {
  local input="$1"
  local clean
  local hash
  clean=$(echo "$input" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]' | cut -c1-3)
  hash=$(echo -n "$input" | md5sum | cut -c1-3)
  echo "${clean}${hash}"
}

# extract k8s namespace name based on the branch and environment
get_namespace_name() {
  local isMainBranch="$1"
  local appName="$2"
  local releaseVersion="$3"
  local altEnvironment="$4"

  if [[ "$isMainBranch" == "True" ]]; then
        namespace=$(grep '^namespace:' "$appName"/helm/"$appName"/values.yaml | awk -F':*' '{print $2}')
        if [ "$altEnvironment" == "SND" ]
        then
          namespaceFulllName=$(echo "$namespace"-"$altEnvironment"2 | awk '{ print tolower($0) }')
        else
          namespaceFulllName=$(echo "$namespace"-"$altEnvironment" | awk '{ print tolower($0) }')
        fi
  else
    namespace=$appName-$releaseVersion
    namespaceFulllName="${namespace//./-}"
  fi
  echo "$namespaceFulllName"
}

# function to get managed identity and service account federation name based on the branch and environment
get_federation_name() {
  local appName="$1"
  local altEnvironment="$2"
  local releaseVersion="$3"

  if [[ "$isMainBranch" == "True" ]]; then
    federationName=$(echo "$appName"-"$altEnvironment" | awk '{ print tolower($0) }')
  else
    federationName=$(echo "$appName"-"$releaseVersion" | awk '{ print tolower($0) }')

  fi

  result="${federationName//./-}"
  echo "$result"
}

# Creating temproray resource names for resources which are in use for pr(beta) deployment 
get_temp_resource_name() {
  local repoName="$1"
  local prNumberOrBranchName="$2"
  local resource_name="$3"

  small_repo_name=$(readable_hash_id "$repoName")
  small_branch_name=$(readable_hash_id "$prNumberOrBranchName")

  echo "t-${small_repo_name}-b${small_branch_name}-${resource_name}"
}


# Convert YAML to key=value, handling 'queue:' substitution
convert_config() {
  local yaml_file="$1"
  local repoName="$2"
  local prNumberOrBranchName="$3"
  local isTemporary="$4"
  local output=""

  # Flatten YAML into key=value using yq and jq
  while IFS='=' read -r key value; do
    # Handle queue substitution
    if [[ "$value" == queue:* ]]; then
      raw_queue="${value#queue:}"
      value=$(get_temp_resource_name "$repoName" "$prNumberOrBranchName" "$raw_queue")
    fi

    # Add PR number suffix if temporary and the key is ingress.endpoint
    if [[ "$isTemporary" == "true" && "$key" == "ingress.endpoint" ]]; then
      value="${value}-${prNumberOrBranchName}"
    fi

    # Append to output
    output+="${key}=${value},"
  done < <(yq eval -o=json "$yaml_file" | jq -r 'paths(scalars) as $p | "\($p | join("."))=\(getpath($p))"')

  # Remove trailing comma
  echo "${output%,}"
}
