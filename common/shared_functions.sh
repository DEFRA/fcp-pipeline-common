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
        namespace=$(yq e '.namespace' "$appName/helm/$appName/values.yaml")
        if [[ "$altEnvironment" == "SND" ]];then
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
  local isMainBranch="$4"

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
  local appName="$1"
  local prNumberOrBranchName="$2"
  local resource_name="$3"

  small_repo_name=$(readable_hash_id "$appName")
  small_branch_name=$(readable_hash_id "$prNumberOrBranchName")

  echo "t-${small_repo_name}-b${small_branch_name}-${resource_name}"
}

# convert_config <yaml_file> <appName> <prNumberOrBranchName> <isTemporary>
convert_config() {
  local yaml_file="$1"
  local appName="$2"
  local prNumberOrBranchName="$3"
  local isTemporary="$4"

  # Read YAML into memory
  local modified_yaml
  modified_yaml="$(<"$yaml_file")"

  # If not temporary, just print original YAML content
  if [[ "$isTemporary" != "True" ]]; then
    printf '%s\n' "$modified_yaml"
    return 0
  fi

  # 1) Append "-<PR>" to ingress.endpoint IF it exists
  if printf '%s' "$modified_yaml" | yq eval -e '.ingress.endpoint' - >/dev/null 2>&1; then
    modified_yaml="$(
      printf '%s' "$modified_yaml" \
      | PR="$prNumberOrBranchName" yq eval '.ingress.endpoint = (.ingress.endpoint + "-" + strenv(PR))' -
    )"
  fi

  # 2) Collect all unique scalar strings that start with "queue:"
  #    (no jq, just yq; -r to unwrap scalars cleanly)
  local qvals
  qvals="$(
    printf '%s' "$modified_yaml" \
    | yq eval -r '.. | select(tag == "!!str" and test("^queue:"))' - \
    | sort -u
  )"

  # 3) For each unique queue:* value, compute replacement via your function and replace globally
  #    We update *all string scalars equal to that exact original value*
  local orig raw new_val
  while IFS= read -r orig; do
    [[ -n "$orig" ]] || continue
    raw="${orig#queue:}"
    new_val="$(get_temp_resource_name "$appName" "$prNumberOrBranchName" "$raw")"

    modified_yaml="$(
      printf '%s' "$modified_yaml" \
      | ORIG="$orig" NEW="$new_val" \
        yq eval '(.. | select(tag == "!!str" and . == strenv(ORIG))) |= strenv(NEW)' -
    )"
  done <<< "$qvals"

  # Output the final YAML
  printf '%s\n' "$modified_yaml"
}

get_provisioning_object() {
  local yaml_file="$1"
  local appName="$2"
  local prNumberOrBranchName="$3"
  local isTemporary="$4"
  
  # === Step 1: Read and convert YAML to JSON
  obj=$(yq eval -o=json "$yaml_file")

  if [[ "$isTemporary" == "True" ]]; then
    # === Step 2: Loop over queues and update names if temporary
    hasQueue=$(yq eval '.resources.service_bus | has("queues")' "$yaml_file")
    if [[ "$hasQueue" == "true" ]]; then
      queue_count=$(echo "$obj" | jq '.resources.service_bus.queues | length')
      for i in $(seq 0 $((queue_count - 1))); do
        old_name=$(echo "$obj" | jq -r ".resources.service_bus.queues[$i].name")
        if [[ "$isTemporary" == "True" ]]; then
          new_name=$(get_temp_resource_name "$appName" "$prNumberOrBranchName" "$old_name")
          obj=$(echo "$obj" | jq --arg idx "$i" --arg new_name "$new_name" '
            .resources.service_bus.queues[$idx | tonumber].name = $new_name
          ')
        fi
      done
    fi
    # === Step 3: Loop over topics and update names if temporary
    hasTopic=$(yq eval '.resources.service_bus | has("topics")' "$yaml_file")
    if [[ "$hasTopic" == "true" ]]; then
      topic_count=$(echo "$obj" | jq '.resources.service_bus.topics | length')
      for i in $(seq 0 $((topic_count - 1))); do
        old_name=$(echo "$obj" | jq -r ".resources.service_bus.topics[$i].name")
        if [[ "$isTemporary" == "True" ]]; then
          new_name=$(get_temp_resource_name "$appName" "$prNumberOrBranchName" "$old_name")
          obj=$(echo "$obj" | jq --arg idx "$i" --arg new_name "$new_name" '
            .resources.service_bus.topics[$idx | tonumber].name = $new_name
          ')
        fi
      done
    fi
  fi
  # === Output the modified JSON
  echo "$obj" | jq .
}

has_database() {
  local yaml_file="$1"
  HAS_DATABASE=$(yq '.resources | has("postgreSql")' "$yaml_file")
  echo "$HAS_DATABASE"
}

get_database_name() {
  local yaml_file="$1"
  local altEnvironment="$2"

  local DB_FULL_NAME=""

  HAS_DATABASE=$(has_database "$yaml_file")
  if [[ "$HAS_DATABASE" == "true" ]]; then
    DATABASE_NAME=$(yq '.resources.postgreSql.name | downcase' "$yaml_file")
    DB_FULL_NAME=$(echo "${DATABASE_NAME}-${altEnvironment}" | awk '{ print tolower($0) }')

  fi

  echo "$DB_FULL_NAME"
}

get_schema_name() {
  local appName="$1"
  local isTemporary="$2"
  local prNumberOrBranchName="$3"

  local schema=""
  if [[ "$isTemporary" == "True" ]]; then
    schema="${appName//-/_}_${prNumberOrBranchName}"
  else
    schema=public
  fi
  echo "$schema"
}

run_db_command() {
  local DATABASE_ADMIN="$1"
  local DATABASE_HOST="$2"
  local DATABASE="$3"
  local COMMAND="$4"

  echo "$COMMAND"
  result=$(docker run --rm --name psql-runner \
                    -e POSTGRES_HOST_AUTH_METHOD=trust \
                    -e PGPASSWORD="$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv)" \
                    -e PGHOST="$DATABASE_HOST" \
                    -e PGUSER="$DATABASE_ADMIN" \
                    -e PGDATABASE="$DATABASE" \
                    alpine/psql -c "$COMMAND")
  echo "$result"
}

run_db_migration() {
  local appName="$1"
  local DATABASE_ADMIN="$2"
  local DATABASE_HOST="$3"
  local SCHEMA="$4"
  local DATABASE="$5"

  local DB_PASSWORD
  DB_PASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv)

  result=$(docker run --rm -v "${PWD}"/"${appName}"/changelog:/liquibase/changelog \
                    liquibase/liquibase:4.12.0 update --driver=org.postgresql.Driver \
    --changeLogFile=/changelog/db.changelog.xml \
    --url=jdbc:postgresql://"$DATABASE_HOST":5432/"$DATABASE" \
    --username="$DATABASE_ADMIN" --password="$DB_PASSWORD" --defaultSchemaName="$SCHEMA" )

  echo "$result"
}

# Usage:
#   get_services_for_decomission            # default 7 days
#   get_services_for_decomission 14         # change age threshold (days)
#   PRETTY=1 get_services_for_decomission   # pretty-print JSON
get_services_for_decomission() {
  DAYS_OLD="${1:-7}"
  PRETTY="${PRETTY:-0}"

  need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
  need kubectl
  need helm
  need jq

  # Helper: derive version tail from namespace
  get_ns_version_tail() {
    ns="$1"
    case "$ns" in
      *-alpha-*) ver_tail="${ns##*-alpha-}"; printf 'alpha-%s' "$ver_tail" ;;
      *-beta-*)  ver_tail="${ns##*-beta-}";  printf 'beta-%s'  "$ver_tail" ;;
      *-beta)    printf 'beta' ;;
      *)         printf '' ;;
    esac
  }

  CUTOFF_EPOCH="$(jq -n --argjson d "$DAYS_OLD" 'now - ($d*24*60*60)')"

  # Namespaces containing -alpha- or -beta
  NS_LIST="$(kubectl get ns -o json \
    | jq -r '.items[]
             | select(.metadata.name | contains("-alpha-") or contains("-beta"))
             | .metadata.name')"

  [ -n "$NS_LIST" ] || { echo '{ "releases": [] }'; return 0; }

  echo "$NS_LIST" | while IFS= read -r ns; do
    [ -n "$ns" ] || continue

    # Pull all helm release secrets (v3) in one go
    sec_json="$(kubectl get secret -n "$ns" \
      -l 'owner=helm' \
      --field-selector 'type=helm.sh/release.v1' \
      -o json 2>/dev/null || printf '{ "items": [] }')"

    # Pick latest revision per release, then most recent release overall
    best="$(printf '%s' "$sec_json" \
      | jq -c '
          .items
          | map({
              name: (.metadata.annotations["meta.helm.sh/release-name"] // .metadata.labels.name // ""),
              ver: ((.metadata.annotations["meta.helm.sh/release-version"] // "0") | tonumber),
              epoch: (.metadata.creationTimestamp | fromdateiso8601)
            })
          | map(select(.name != ""))
          | (group_by(.name) | map(max_by(.ver)))
          | (if length==0 then empty else max_by(.epoch) end)
        ')"

    [ -n "$best" ] || continue

    rel_name="$(printf '%s' "$best" | jq -r '.name')"
    rel_epoch="$(printf '%s' "$best" | jq -r '.epoch')"

    # Age filter
    if [ "$(jq -nr --argjson a "$rel_epoch" --argjson c "$CUTOFF_EPOCH" '$a < $c')" != "true" ]; then
      continue
    fi

    # Determine version tail string from namespace
    versionTail="$(get_ns_version_tail "$ns")"

    # Get values (JSON if possible; fallback to YAML->JSON if yq is present)
    vals_json="$(helm get values "$rel_name" -n "$ns" -o json 2>/dev/null || printf '{}')"
    if [ "$(printf '%s' "$vals_json" | jq 'has("release")')" != "true" ]; then
      if command -v yq >/dev/null 2>&1; then
        vals_json="$(helm get values "$rel_name" -n "$ns" --all -o yaml 2>/dev/null \
          | yq -o=json 2>/dev/null || printf '{}')"
      else
        vals_json="$(helm get values "$rel_name" -n "$ns" --all -o json 2>/dev/null || printf '{}')"
      fi
    fi

    # Extract release block, add namespace + versionTail fields.
    rel_obj="$(printf '%s' "$vals_json" | jq -c \
      --arg ns "$ns" \
      --arg versionTail "$versionTail" \
      '
      select(has("release")) | .release
      | {
          branch:   (.branch   // null),
          dbSchema: (.dbSchema // null),
          dbName:   (.dbName   // null),
          identity: (.identity // null),
          prNo:     (.prNo     // null),
          repo:     (.repo     // null)
        }
      | . + { namespace: $ns, versionTail: ($versionTail // null) }
      | select(.branch != null or .prNo != null or .repo != null)
      ')"

    [ -n "$rel_obj" ] && printf '%s\n' "$rel_obj"
  done | if [ "$PRETTY" = "1" ]; then jq -s '{releases: .}'; else jq -c -s '{releases: .}'; fi
}


# Resolve principalId of a user-assigned managed identity (by name)
get_principal_id() {
  local identity_name="$1"
  local resource_group="$2" # fall back to SB RG if not provided
  az identity show --name "$identity_name" --resource-group "$resource_group" --query principalId -o tsv
}

list_all_role_assignments_for_principal() {
  local principal_id="$1"
  az role assignment list \
    --assignee-object-id "$principal_id" \
    --all -o json
}

delete_sb_role_assignments_by_entity_name() {
  identity_name="$1"   # UAMI name
  identity_rg="$2"     # RG of the UAMI
  entity_name="$3"     # queue or topic name

  if [ -z "$identity_name" ] || [ -z "$identity_rg" ] || [ -z "$entity_name" ]; then
    echo "Usage: delete_sb_role_assignments_by_entity_name <identity_name> <identity_rg> <entity_name>" >&2
    return 2
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed (try 'brew install jq')." >&2
    return 2
  fi

  principal_id="$(get_principal_id "$identity_name" "$identity_rg")"
  if [ -z "$principal_id" ]; then
    echo "Could not resolve principalId for identity '$identity_name' in RG '$identity_rg'." >&2
    return 1
  fi

  assignments="$(list_all_role_assignments_for_principal "$principal_id")"

  # we need to match scopes that contain "/<entity_name>/" or end with "/<entity_name>"
  ids="$(printf '%s' "$assignments" | jq -r --arg n "$entity_name" '
    .[]? 
    | select(.scope? != null) 
    | . as $a
    | ($a.scope | ascii_downcase) as $s
    | ($n | ascii_downcase) as $ename
    | select(
        ($s | test("/" + $ename + "/"))
        or
        ($s | test("/" + $ename + "$"))
      )
    | .id
  ')"

  if [ -z "$ids" ]; then
    echo "No role assignments found for principal $principal_id scoped to '$entity_name'."
    return 0
  fi

  echo "Deleting role assignments scoped to '$entity_name':"
  printf '%s\n' "$ids" | while IFS= read -r id; do
    [ -z "$id" ] && continue
    if [ "$DRY_RUN" = "1" ]; then
      echo "[DRY RUN] az role assignment delete --ids '$id'"
    else
      az role assignment delete --ids "$id"
    fi
  done
}


delete_federations() {
  local federation_list="$1"
  local identity="$2"
  local resource_group="$3"

  for fed in ${federation_list//,/ }; do
    echo "Deleting federation: $fed"
    az identity federated-credential delete \
      --identity-name "$identity" \
      --resource-group "$resource_group" \
      --name "$fed" \
      --yes
  done

}

delete_queues() {
  local queue_list="$1"
  local namespace="$2"
  local resource_group="$3"

  for queue in ${queue_list//,/ }; do
    echo "Deleting queue: $queue"
    az servicebus queue delete \
      --resource-group "$resource_group" \
      --namespace-name "$namespace" \
      --name "$queue"
  done
}

delete_topics() {
  local topic_list="$1"
  local namespace="$2"
  local resource_group="$3"

  for topic in ${topic_list//,/ }; do
    echo "Deleting topic: $topic"
    az servicebus topic delete \
      --resource-group "$resource_group" \
      --namespace-name "$namespace" \
      --name "$topic"
  done
}