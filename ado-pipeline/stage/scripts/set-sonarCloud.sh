#!/bin/bash

set -euo pipefail

# --- Parse Arguments ---
usage() {
  echo "Usage: $0 -r <RepositoryName> -k <SonarKey> [-o <SonarOrganisation>]"
  exit 1
}

REPOSITORY_NAME=""
SONAR_KEY=""
SONAR_ORG="defra"

while getopts ":r:k:o:" opt; do
  case $opt in
    r) REPOSITORY_NAME="$OPTARG" ;;
    k) SONAR_KEY="$OPTARG" ;;
    o) SONAR_ORG="$OPTARG" ;;
    *) usage ;;
  esac
done

if [[ -z "$REPOSITORY_NAME" || -z "$SONAR_KEY" ]]; then
  usage
fi

# --- Variables ---
SONAR_URL="https://sonarcloud.io"
ENCODED_AUTH=$(echo -n "${SONAR_KEY}:" | base64)
HEADERS=(-H "Authorization: Basic ${ENCODED_AUTH}" -H "Accept: application/json")

START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FUNCTION_NAME="SonarCloudProjectCheck"
EXIT_CODE=-1
ENABLE_DEBUG="${SYSTEM_DEBUG:-false}"
SET_HOST_EXIT_CODE="${TF_BUILD:-false}"

log_debug() {
  [[ "$ENABLE_DEBUG" == "true" ]] && echo "[DEBUG] $1"
}

# --- Script Start ---
echo "$FUNCTION_NAME started at $START_TIME"
log_debug "RepositoryName=$REPOSITORY_NAME"
log_debug "SonarKey=$SONAR_KEY"
log_debug "SonarOrganisation=$SONAR_ORG"

{
  # --- Check if project exists ---
  log_debug "Checking existence of the project '$REPOSITORY_NAME'..."
  RESPONSE=$(curl -s -f "${HEADERS[@]}" \
    "$SONAR_URL/api/components/tree?component=$REPOSITORY_NAME&qualifiers=TRK") || RESPONSE=""

  if [[ -z "$RESPONSE" || "$RESPONSE" == *"'$REPOSITORY_NAME' not found"* ]]; then
    echo "Creating project '$REPOSITORY_NAME' on '$SONAR_ORG' organisation."
    curl -s -f -X POST "${HEADERS[@]}" \
      -d "name=$REPOSITORY_NAME" \
      -d "project=$REPOSITORY_NAME" \
      -d "organization=$SONAR_ORG" \
      -d "visibility=public" \
      -d "newCodeDefinitionType=previous_version" \
      -d "newCodeDefinitionValue=previous_version" \
      "$SONAR_URL/api/projects/create"

    log_debug "Renaming default branch of the project '$REPOSITORY_NAME' to 'main'."
    curl -s -f -X POST "${HEADERS[@]}" \
      -d "project=$REPOSITORY_NAME" \
      -d "name=main" \
      "$SONAR_URL/api/project_branches/rename"
  else
    echo "The project '$REPOSITORY_NAME' already exists on '$SONAR_ORG' organisation."
  fi

  EXIT_CODE=0
} || {
  EXIT_CODE=-2
  echo "An error occurred during processing." >&2
}

# --- Script End ---
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Parse timestamps safely
START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +%s)
END_EPOCH=$(date -d "$END_TIME" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$END_TIME" +%s)
DURATION=$((END_EPOCH - START_EPOCH))

echo "$FUNCTION_NAME finished at $END_TIME (duration ${DURATION}s) with exit code $EXIT_CODE"
if [[ "$SET_HOST_EXIT_CODE" == "true" ]]; then
  log_debug "Setting host exit code"
fi

exit $EXIT_CODE
