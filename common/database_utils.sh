#!/usr/bin/bash
# Contains functions related to database functions

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

  result=$(docker run --rm -v "$(Agent.BuildDirectory)/s/"/"${appName}"/changelog:/liquibase/changelog \
                    liquibase/liquibase:4.12.0 update --driver=org.postgresql.Driver \
    --changeLogFile=/changelog/db.changelog.xml \
    --url=jdbc:postgresql://"$DATABASE_HOST":5432/"$DATABASE" \
    --username="$DATABASE_ADMIN" --password="$DB_PASSWORD" --defaultSchemaName="$SCHEMA" )

  echo "$result"
}
