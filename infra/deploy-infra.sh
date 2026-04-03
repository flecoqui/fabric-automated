#!/bin/sh
##########################################################################################################################################################################################
#- Purpose: Script used to install pre-requisites, deploy/undeploy service, start/stop service, test service
#- Parameters are:
#- [-a] ACTION - value: azure-login, deploy-public-fabric, deploy-public-datasource, deploy-private-fabric, deploy-private-datasource, 
#- [-e] environment - "dev", "stag", "preprod", "prod"
#- [-c] Sets the configuration file
#- [-t] Sets deployment Azure Tenant Id
#- [-s] Sets deployment Azure Subcription Id
#- [-r] Sets the Azure Region for the deployment#
# if [ -z "$BASH_VERSION" ]
# then
#    echo Force bash
#    exec bash "$0" "$@"
# fi
# executable
###########################################################################################################################################################################################
set -u
# echo  "$0" "$@"
BASH_SCRIPT=$(readlink -f "$0")
# Get the directory where the bash script is located
SCRIPTS_DIRECTORY=$(dirname "$BASH_SCRIPT")



##############################################################################
# colors for formatting the output
##############################################################################
# shellcheck disable=SC2034
{
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
}
##############################################################################
#- function used to check whether an error occurred
##############################################################################
checkError() {
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "${RED}"
        echo "An error occurred exiting from the current bash${NC}"
        exit 1
    fi
}
##############################################################################
#- print functions
##############################################################################
printMessage(){
    echo "${GREEN}$1${NC}"
}
printWarning(){
    echo "${YELLOW}$1${NC}"
}
printError(){
    echo "${RED}$1${NC}"
}
printProgress(){
    echo "${BLUE}$1${NC}"
}
#######################################################
#- used to print out script usage
#######################################################
usage() {
    echo
    echo "Arguments:"
    printf " -a  Sets deploy-infra ACTION { azure-login, deploy-public-fabric, deploy-public-datasource, deploy-private-fabric, deploy-private-datasource, remove-public-fabric, remove-private-fabric, remove-public-datasource, remove-private-datasource}\n"
    printf " -e  Sets the environment - by default 'dev' ('dev', 'test', 'stag', 'prep', 'prod')\n"
    printf " -s  Sets subscription id \n"
    printf " -t  Sets tenant id\n"
    printf " -c  Sets the configuration file\n"
    printf " -r  Sets the Azure Region for the deployment\n"
    echo
    echo "Example:"
    printf " bash ./deploy-infra.sh -a deploy-public-fabric \n"
}
##############################################################################
#- readConfigurationFile: Update configuration file
#  arg 1: Configuration file path
##############################################################################
readConfigurationFile(){
    file="$1"

    set -o allexport
    # shellcheck disable=SC1090
    . "$file"
    set +o allexport
}
##############################################################################
#- readConfigurationFileValue: Read one value in  configuration file
#  arg 1: Configuration file path
#  arg 2: Variable Name
##############################################################################
readConfigurationFileValue(){
    configFile="$1"
    variable="$2"

    grep "${variable}=*"  < "${configFile}" | head -n 1 | sed "s/${variable}=//g"
}
##############################################################################
#- updateConfigurationFile: Update configuration file
#  arg 1: Configuration file path
#  arg 2: Variable Name
#  arg 3: Value
##############################################################################
updateConfigurationFile(){
    configFile="$1"
    variable="$2"
    value="$3"

    count=$(grep "${variable}=.*" -c < "$configFile") || true
    if [ "${count}" != 0 ]; then
        ESCAPED_REPLACE=$(printf '%s\n' "${value}" | sed -e 's/[\/&]/\\&/g')
        sed -i "s/${variable}=.*/${variable}=${ESCAPED_REPLACE}/g" "${configFile}"  2>/dev/null
    elif [ "${count}" = 0 ]; then
        # shellcheck disable=SC2046
        if [ $(tail -c1 "${configFile}" | wc -l) -eq 0 ]; then
            echo "" >> "${configFile}"
        fi
        echo "${variable}=${value}" >> "${configFile}"
    fi
    printProgress "${variable}=${value}"
}
##############################################################################
#- Get Public Fabric Resource Group Name
#  arg 1: Resource Group Suffix
##############################################################################
setAzureResourceNames()
{
    env="$1"
    visibility="$2"
    suffix="$3"
    RG="$4"

    printProgress "Getting Azure resource names for env='$env' visibility='$visibility' suffix='$suffix' from bicep file: $SCRIPTS_DIRECTORY/bicep/naming-convention.bicep"
    DEPLOY_NAME=$(date +"%y%m%d%H%M%S")
    cmd="az deployment group create --name \"${DEPLOY_NAME}\" --resource-group \"${RG}\" --template-file $SCRIPTS_DIRECTORY/bicep/naming-convention.bicep --parameters suffix=\"${suffix}\" environment=\"${env}\" visibility=\"${visibility}\""
    # printProgress "$cmd"
    eval "$cmd" 2>/dev/null >/dev/null|| true
    checkError

    cmd="az deployment group show --name \"${DEPLOY_NAME}\" --resource-group \"${RG}\" --query properties.outputs"
    #printProgress "$cmd"
    RESULT=$(eval "$cmd")
    checkError
    printProgress "RESULT: $RESULT"

    AZURE_VNET_NAME=$(echo ${RESULT}  | jq -r '.vnetName.value' 2>/dev/null)
    echo "AZURE_VNET_NAME: $AZURE_VNET_NAME"
    AZURE_SUBNET_NAME=$(echo ${RESULT}  | jq -r '.privateEndpointSubnetName.value' 2>/dev/null)
    echo "AZURE_SUBNET_NAME: $AZURE_SUBNET_NAME"
    AZURE_DATAGW_SUBNET_NAME=$(echo ${RESULT}  | jq -r '.datagwSubnetName.value' 2>/dev/null)
    echo "AZURE_DATAGW_SUBNET_NAME: $AZURE_DATAGW_SUBNET_NAME"
    AZURE_GATEWAY_SUBNET_NAME=$(echo ${RESULT}  | jq -r '.gatewaySubnetName.value' 2>/dev/null)
    echo "AZURE_GATEWAY_SUBNET_NAME: $AZURE_GATEWAY_SUBNET_NAME"
    AZURE_DNS_DELEGATION_SUBNET_NAME=$(echo ${RESULT}  | jq -r '.dnsDelegationSubNetName.value' 2>/dev/null)
    echo "AZURE_DNS_DELEGATION_SUBNET_NAME: $AZURE_DNS_DELEGATION_SUBNET_NAME"

    AZURE_FABRIC_ACCOUNT_NAME=$(echo ${RESULT}  | jq -r '.fabricAccountName.value' 2>/dev/null)
    echo "AZURE_FABRIC_ACCOUNT_NAME: $AZURE_FABRIC_ACCOUNT_NAME"
    AZURE_FABRIC_WORKSPACE_NAME=$(echo ${RESULT}  | jq -r '.fabricWorkspaceName.value' 2>/dev/null)
    echo "AZURE_FABRIC_WORKSPACE_NAME: $AZURE_FABRIC_WORKSPACE_NAME"

    AZURE_STORAGE_ACCOUNT_NAME=$(echo ${RESULT}  | jq -r '.storageAccountName.value' 2>/dev/null)
    echo "AZURE_STORAGE_ACCOUNT_NAME: $AZURE_STORAGE_ACCOUNT_NAME"
    AZURE_STORAGE_ACCOUNT_DEFAULT_CONTAINER_NAME=$(echo ${RESULT}  | jq -r '.storageAccountDefaultContainerName.value' 2>/dev/null)
    echo "AZURE_STORAGE_ACCOUNT_DEFAULT_CONTAINER_NAME: $AZURE_STORAGE_ACCOUNT_DEFAULT_CONTAINER_NAME"
    AZURE_COSMOS_DB_NAME=$(echo ${RESULT}  | jq -r '.cosmosDBName.value' 2>/dev/null)
    echo "AZURE_COSMOS_DB_NAME: $AZURE_COSMOS_DB_NAME"
    AZURE_POSTGRESQL_NAME=$(echo ${RESULT}  | jq -r '.postgreSqlServerName.value' 2>/dev/null)
    echo "AZURE_POSTGRESQL_NAME: $AZURE_POSTGRESQL_NAME"
    
    AZURE_KEY_VAULT_NAME=$(echo ${RESULT}  | jq -r '.keyVaultName.value' 2>/dev/null)
    echo "AZURE_KEY_VAULT_NAME: $AZURE_KEY_VAULT_NAME"

    AZURE_DATAGW_VM_NAME=$(echo ${RESULT}  | jq -r '.datagwVMName.value' 2>/dev/null)
    echo "AZURE_DATAGW_VM_NAME: $AZURE_DATAGW_VM_NAME"
    AZURE_DATAGW_VM_LOGIN_SECRET_NAME=$(echo ${RESULT}  | jq -r '.datagwVMLoginSecretName.value' 2>/dev/null)
    echo "AZURE_DATAGW_VM_LOGIN_SECRET_NAME: $AZURE_DATAGW_VM_LOGIN_SECRET_NAME"
    AZURE_DATAGW_VM_PASSWORD_SECRET_NAME=$(echo ${RESULT}  | jq -r '.datagwVMPassSecretName.value' 2>/dev/null)
    echo "AZURE_DATAGW_VM_PASSWORD_SECRET_NAME: $AZURE_DATAGW_VM_PASSWORD_SECRET_NAME"
    AZURE_DATAGW_VM_RECOVERY_KEY_SECRET_NAME=$(echo ${RESULT}  | jq -r '.datagwVMRecoveryKeySecretName.value' 2>/dev/null)
    echo "AZURE_DATAGW_VM_RECOVERY_KEY_SECRET_NAME: $AZURE_DATAGW_VM_RECOVERY_KEY_SECRET_NAME"
    AZURE_DATAGW_CERTIFICATE_SECRET_NAME=$(echo ${RESULT}  | jq -r '.datagwCertificateSecretName.value' 2>/dev/null)
    echo "AZURE_DATAGW_CERTIFICATE_SECRET_NAME: $AZURE_DATAGW_CERTIFICATE_SECRET_NAME"
    AZURE_DATAGW_CERTIFICATE_PASSWORD_SECRET_NAME=$(echo ${RESULT}  | jq -r '.datagwCertificatePassSecretName.value' 2>/dev/null)
    echo "AZURE_DATAGW_CERTIFICATE_PASSWORD_SECRET_NAME: $AZURE_DATAGW_CERTIFICATE_PASSWORD_SECRET_NAME"
    AZURE_DATAGW_CERTIFICATE_NAME=$(echo ${RESULT}  | jq -r '.datagwCertificateName.value' 2>/dev/null)
    echo "AZURE_DATAGW_CERTIFICATE_NAME: $AZURE_DATAGW_CERTIFICATE_NAME"
    AZURE_DATAGW_APP_NAME=$(echo ${RESULT}  | jq -r '.datagwAppName.value' 2>/dev/null)
    echo "AZURE_DATAGW_APP_NAME: $AZURE_DATAGW_APP_NAME"

    AZURE_VPN_GATEWAY_PIP_NAME=$(echo ${RESULT}  | jq -r '.vpnGatewayPublicIpName.value' 2>/dev/null)
    echo "AZURE_VPN_GATEWAY_PIP_NAME: $AZURE_VPN_GATEWAY_PIP_NAME"
    AZURE_DNS_RESOLVER_NAME=$(echo ${RESULT}  | jq -r '.dnsResolverName.value' 2>/dev/null)
    echo "AZURE_DNS_RESOLVER_NAME: $AZURE_DNS_RESOLVER_NAME"

    AZURE_POSTGRESQL_ADMINISTRATOR_LOGIN_SECRET_NAME=$(echo ${RESULT}  | jq -r '.postgreSqlAdministratorLoginSecretName.value' 2>/dev/null)
    echo "AZURE_POSTGRESQL_ADMINISTRATOR_LOGIN_SECRET_NAME: $AZURE_POSTGRESQL_ADMINISTRATOR_LOGIN_SECRET_NAME"
    AZURE_POSTGRESQL_ADMINISTRATOR_PASSWORD_SECRET_NAME=$(echo ${RESULT}  | jq -r '.postgreSqlAdministratorPassSecretName.value' 2>/dev/null)
    echo "AZURE_POSTGRESQL_ADMINISTRATOR_PASSWORD_SECRET_NAME: $AZURE_POSTGRESQL_ADMINISTRATOR_PASSWORD_SECRET_NAME"

    AZURE_RESOURCE_GROUP_FABRIC_NAME=$(echo ${RESULT}  | jq -r '.resourceGroupFabricName.value' 2>/dev/null)
    echo "AZURE_RESOURCE_GROUP_FABRIC_NAME: $AZURE_RESOURCE_GROUP_FABRIC_NAME"
    AZURE_RESOURCE_GROUP_DATASOURCE_NAME=$(echo ${RESULT}  | jq -r '.resourceGroupDatasourceName.value' 2>/dev/null)
    echo "AZURE_RESOURCE_GROUP_DATASOURCE_NAME: $AZURE_RESOURCE_GROUP_DATASOURCE_NAME"
}


##############################################################################
#- Get Fabric Resource Group Name
#  arg 1: Env
#  arg 2: Visibility
#  arg 3: Suffix
##############################################################################
getFabricResourceGroupName()
{
    env="$1"
    visibility="$2"
    suffix="$3"
    if [ ! -z "${AZURE_DEFAULT_FABRIC_RESOURCE_GROUP+x}" ] ; then
        if [ -z "${AZURE_DEFAULT_FABRIC_RESOURCE_GROUP}" ] && [ "${AZURE_DEFAULT_FABRIC_RESOURCE_GROUP}" != "" ] ; then
            echo "${AZURE_DEFAULT_FABRIC_RESOURCE_GROUP}"
            return
        fi
    fi
    if [ -z "${1+x}" ] ; then
        echo "rgfabricdevpub"
    else
        echo "rgfabric${env}${visibility}${suffix}"
    fi
}
##############################################################################
#- Get Datasource Resource Group Name
#  arg 1: Env
#  arg 2: Visibility
#  arg 3: Suffix
##############################################################################
getDatasourceResourceGroupName()
{
    env="$1"
    visibility="$2"
    suffix="$3"
    if [ ! -z "${AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP+x}" ] ; then
        if [ "${AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP}" != "" ] ; then
            echo "${AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP}"
            return
        fi
    fi
    if [ -z "${1+x}" ] ; then
        echo "rgdatasourcedevpub"
    else
        echo "rgdatasource${env}${visibility}${suffix}"
    fi
}
##############################################################################
#- Get Storage Account Name
#  arg 1: Env
#  arg 2: Visibility
#  arg 3: Suffix
##############################################################################
getStorageAccountName()
{
    env="$1"
    visibility="$2"
    suffix="$3"
    echo "st${env}${visibility}${suffix}"
}
##############################################################################
#- Get Key Vault Name
#  arg 1: Env
#  arg 2: Visibility
#  arg 3: Suffix
##############################################################################
getKeyVaultName()
{
    env="$1"
    visibility="$2"
    suffix="$3"
    echo "kv${env}${visibility}${suffix}"
}
##############################################################################
#- azure Login
##############################################################################
azLogin() {
    # Check if current process's user is logged on Azure
    if [ ! -z "${AZURE_SUBSCRIPTION_ID+x}" ] && [ ! -z "${AZURE_TENANT_ID+x}" ]; then
        SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
        TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true
        if [ "$AZURE_SUBSCRIPTION_ID" = "$SUBSCRIPTION_ID" ] && [ "$AZURE_TENANT_ID" = "$TENANT_ID" ]; then
            printMessage "Already logged in Azure CLI"
            return
        fi
    fi
    if [ ! -z "${AZURE_TENANT_ID+x}" ]; then
        az login --tenant "$AZURE_TENANT_ID" --only-show-errors
    else
        az login --only-show-errors
    fi
    if [ ! -z "${AZURE_SUBSCRIPTION_ID+x}" ]; then
        az account set -s "$AZURE_SUBSCRIPTION_ID" 2>/dev/null || azOk=false
    fi
    AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
    AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true
}
##############################################################################
#- checkLoginAndSubscription
##############################################################################
checkLoginAndSubscription() {
    az account show -o none
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        printf "\nYou seems disconnected from Azure, running 'az login'."
        azLogin
    fi
    CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
    if [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ "$AZURE_SUBSCRIPTION_ID" != "$CURRENT_SUBSCRIPTION_ID" ]; then
        # query subscriptions
        printf  "\nYou have access to the following subscriptions:"
        az account list --query '[].{name:name,"subscription Id":id}' --output table

        printf "\nYour current subscription is:"
        az account show --query '[name,id]'
        # shellcheck disable=SC2154
        if [ -z "$CURRENT_SUBSCRIPTION_ID" ]; then
            echo  "
            You will need to use a subscription with permissions for creating service principals (owner role provides this).
            If you want to change to a different subscription, enter the name or id.
            Or just press enter to continue with the current subscription."
            read -r  ">> " SUBSCRIPTION_ID

            if ! test -z "$SUBSCRIPTION_ID"
            then
                az account set -s "$SUBSCRIPTION_ID"
                printf  "\nNow using:"
                az account show --query '[name,id]'
                CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
            fi
        fi
    fi
}
##############################################################################
#- isStorageAccountNameAvailable
##############################################################################
isStorageAccountNameAvailable(){
    name=$1
    if [ "$(az storage account check-name --name "${name}" | jq -r '.nameAvailable'  2>/dev/null)" =  "false" ]
    then
        echo "false"
    else
        echo "true"
    fi
}
##############################################################################
#- isKeyVaultNameAvailable
##############################################################################
isKeyVaultNameAvailable(){
    subscriptionId=$1
    name=$2
    if [ "$(az rest --method post --uri "https://management.azure.com/subscriptions/${subscriptionId}/providers/Microsoft.KeyVault/checkNameAvailability?api-version=2019-09-01" --headers "Content-Type=application/json" --body "{\"name\": \"${name}\",\"type\": \"Microsoft.KeyVault/vaults\"}" 2>/dev/null | jq -r ".nameAvailable"  2>/dev/null)"  =  "false" ]
    then
        echo "false"
    else
        echo "true"
    fi
}
##############################################################################
#- isResourceGroupNameAvailable
##############################################################################
isResourceGroupNameAvailable(){
    name=$1
    NAME=$(az group show -n "${name}" --query name -o tsv 2> /dev/null)
    if [ ! -z "${NAME}" ]; then
        FOUND="false"
    else
        FOUND="true"
    fi
    echo "$FOUND"
}
##############################################################################
# getAvailableSuffix
##############################################################################
getAvailableSuffix() {
    SUBSCRIPTION_ID=$1
    FOUND="true"
    while [ "$FOUND" = "true" ]; do
        SUFFIX=$(shuf -i 1000-9999 -n 1)

        RG=$(getFabricResourceGroupName "${AZURE_ENVIRONMENT}" "pub" "$SUFFIX")
        if [ "$(isResourceGroupNameAvailable "$RG")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
        RG=$(getFabricResourceGroupName "${AZURE_ENVIRONMENT}" "pri" "$SUFFIX")
        if [ "$(isResourceGroupNameAvailable "$RG")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
        RG=$(getDatasourceResourceGroupName "${AZURE_ENVIRONMENT}" "pub"  "$SUFFIX")
        if [ "$(isResourceGroupNameAvailable "$RG")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
        RG=$(getDatasourceResourceGroupName "${AZURE_ENVIRONMENT}" "pri"  "$SUFFIX")
        if [ "$(isResourceGroupNameAvailable "$RG")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
        ST=$(getStorageAccountName "$AZURE_ENVIRONMENT" "pri" "$SUFFIX")
        if [ "$(isStorageAccountNameAvailable "$ST")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
        ST=$(getStorageAccountName "$AZURE_ENVIRONMENT" "pub" "$SUFFIX")
        if [ "$(isStorageAccountNameAvailable "$ST")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
        KV=$(getKeyVaultName "$AZURE_ENVIRONMENT" "pri" "$SUFFIX")
        if [ "$(isKeyVaultNameAvailable "$SUBSCRIPTION_ID" "$KV")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
        KV=$(getKeyVaultName "$AZURE_ENVIRONMENT" "pub" "$SUFFIX")
        if [ "$(isKeyVaultNameAvailable "$SUBSCRIPTION_ID" "$KV")" = "false" ]; then
            FOUND="true"
            continue
        else
            FOUND="false"
        fi
    done
    echo "$SUFFIX"
    exit
}
##############################################################################
#- checkAzureConfiguration
##############################################################################
checkAzureConfiguration() {
    az account show -o none
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        printf "\nYou seems disconnected from Azure, running 'az login'."
        azLogin
    fi
    CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
    CURRENT_TENANT_ID=$(az account show --query 'tenantId' --output tsv)
    if [ -z "${AZURE_SUBSCRIPTION_ID+x}" ] || [ "$AZURE_SUBSCRIPTION_ID" != "$CURRENT_SUBSCRIPTION_ID" ]; then
        # query subscriptions
        # printf  "\nYou have access to the following subscriptions:"
        # az account list --query '[].{name:name,"subscription Id":id}' --output table

        # printf "\nYour current subscription is:"
        # az account show --query '[name,id]'
        # shellcheck disable=SC2154
        if [ -z "$CURRENT_SUBSCRIPTION_ID" ]; then
            echo  "
            You will need to use a subscription with permissions for creating service principals (owner role provides this).
            If you want to change to a different subscription, enter the name or id.
            Or just press enter to continue with the current subscription."
            read -r  ">> " SUBSCRIPTION_ID

            if ! test -z "$SUBSCRIPTION_ID"
            then
                az account set -s "$SUBSCRIPTION_ID"
                printf  "\nNow using:"
                az account show --query '[name,id]'
                CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
                CURRENT_TENANT_ID=$(az account show --query 'tenantId' --output tsv)
            fi
        fi
    fi
    # if variable CONFIGURATION_FILE is set, read varaiable values in configuration file.
    if [ "$CONFIGURATION_FILE" ]; then
        if [ -f "$CONFIGURATION_FILE" ]; then
            CONFIG_SUBSCRIPTION_ID=$(readConfigurationFileValue "$CONFIGURATION_FILE" "AZURE_SUBSCRIPTION_ID")
            if [ ! -z "${CONFIG_SUBSCRIPTION_ID}" ] && [ "$CONFIG_SUBSCRIPTION_ID" != "$CURRENT_SUBSCRIPTION_ID" ]; then
                printProgress "Updating a Azure Configuration file: $CONFIGURATION_FILE value: AZURE_SUBSCRIPTION_ID=$CURRENT_SUBSCRIPTION_ID..."
                updateConfigurationFile "$CONFIGURATION_FILE" "AZURE_SUBSCRIPTION_ID" "$CURRENT_SUBSCRIPTION_ID"
            fi
            CONFIG_TENANT_ID=$(readConfigurationFileValue "$CONFIGURATION_FILE" "AZURE_TENANT_ID")
            if [ ! -z "${CONFIG_TENANT_ID}" ] && [ "$CONFIG_TENANT_ID" != "$CURRENT_TENANT_ID" ]; then
                printProgress "Updating a Azure Configuration file: $CONFIGURATION_FILE value: AZURE_TENANT_ID=$CURRENT_TENANT_ID..."
                updateConfigurationFile "$CONFIGURATION_FILE" "AZURE_TENANT_ID" "$CURRENT_TENANT_ID"
            fi
            CONFIG_SUFFIX=$(readConfigurationFileValue "$CONFIGURATION_FILE" "AZURE_SUFFIX")
            if [ -z "${CONFIG_SUFFIX}" ]; then
                printProgress "Updating a Azure Configuration file: $CONFIGURATION_FILE value: AZURE_SUFFIX=$AZURE_SUFFIX..."
                AZURE_SUFFIX="$(getAvailableSuffix ${CURRENT_SUBSCRIPTION_ID})"
                printProgress "Using AZURE_SUFFIX=$AZURE_SUFFIX"
                updateConfigurationFile "$CONFIGURATION_FILE" "AZURE_SUFFIX" "$AZURE_SUFFIX"
            fi
        else
            printProgress "Creating a new Azure Configuration file: $CONFIGURATION_FILE..."
            AZURE_SUFFIX="$(getAvailableSuffix ${CURRENT_SUBSCRIPTION_ID})"
            printProgress "Using AZURE_SUFFIX=$AZURE_SUFFIX"
            cat > "$CONFIGURATION_FILE" << EOF
AZURE_REGION="${AZURE_REGION}"
AZURE_SUFFIX="${AZURE_SUFFIX}"
AZURE_SUBSCRIPTION_ID=${CURRENT_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${CURRENT_TENANT_ID}
AZURE_ENVIRONMENT=${AZURE_ENVIRONMENT}
AZURE_DEFAULT_FABRIC_RESOURCE_GROUP=""
AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP=""
EOF
        fi
        readConfigurationFile "$CONFIGURATION_FILE"
    fi
}
##############################################################################
#- getCurrentObjectId
##############################################################################
getCurrentObjectId() {
  UserObjectId=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true
  ServicePrincipalId=
  if [ -z "$UserObjectId" ]; then
      # shellcheck disable=SC2154
      ServicePrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null)
      ObjectId="${ServicePrincipalId}"
  else
      ObjectId="${UserObjectId}"
  fi
  echo "$ObjectId"
}
##############################################################################
#- getCurrentUserPrincipalName
##############################################################################
getCurrentUserPrincipalName() {
  UserPrincipalName=$(az ad signed-in-user show --query userPrincipalName --output tsv 2>/dev/null) || true
  if [ -z "$UserPrincipalName" ]; then
      # shellcheck disable=SC2154
      ServicePrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null)
      ObjectId="${ServicePrincipalId}"
  else
      ObjectId="${UserPrincipalName}"
  fi
  echo "$ObjectId"
}
##############################################################################
#- getCurrentObjectType
##############################################################################
getCurrentObjectType() {
  UserObjectId=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true
  ObjectType="User"
  if [ -z "$UserObjectId" ]; then
      # shellcheck disable=SC2154
      ServicePrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null)
      ObjectType="ServicePrincipal"
  fi
  echo "$ObjectType"
}
##############################################################################
#- createFabricWorkspace
##############################################################################
createFabricWorkspace() {
  TOKEN=$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)
  FABRIC_ACCOUNT_NAME=$1
  WORKSPACE_NAME=$2
  SKU=$3
  FABRIC_CAPACITY_ID=$(curl --request GET \
  --url "https://api.fabric.microsoft.com/v1/capacities" \
  --header "Authorization: Bearer $TOKEN" --fail --silent --show-error  | jq -r ".value[] | select(.sku==\"${SKU}\"  and .displayName==\"${FABRIC_ACCOUNT_NAME}\") | .id")    
  
  curl --request POST \
    --url "https://api.fabric.microsoft.com/v1/workspaces" \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/json" \
    --fail --silent --show-error \
    --data "{\"displayName\": \"${WORKSPACE_NAME}\",\"capacityId\": \"${FABRIC_CAPACITY_ID}\"}"    
}
##############################################################################
#- getFabricWorkspaceId
##############################################################################
getFabricWorkspaceId() {
TOKEN=$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)
  WORKSPACE_NAME=$1
  curl --request GET \
    --url "https://api.fabric.microsoft.com/v1/workspaces" \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/json" \
    --fail --silent --show-error | jq -r ".value[] | select(.displayName==\"${WORKSPACE_NAME}\") | .id"     
}
##############################################################################
#- createFabricWorkspaceIdentity
##############################################################################
createFabricWorkspaceIdentity() {
WORKSPACE_ID=$1
TOKEN=$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)

curl --request POST \
    --url "https://api.fabric.microsoft.com/v1/workspaces/${WORKSPACE_ID}/provisionIdentity" \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/json" \
    --data '' \
    --fail --silent --show-error 
}

##############################################################################
#- getFabricWorkspaceIdentity
##############################################################################
getFabricWorkspaceIdentity() {
  WORKSPACE_ID=$1
  TOKEN=$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)

  curl --request GET \
    --url "https://api.fabric.microsoft.com/v1/workspaces/${WORKSPACE_ID}" \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/json" \
    --fail --silent --show-error | jq -r '.workspaceIdentity.servicePrincipalId'
}

##############################################################################
#- getFabricToken
##############################################################################
getFabricToken() {
  bearer_token=$(az account get-access-token --resource https://fabric.azure.net --output json | jq -r .accessToken)
  echo "$bearer_token"
}


##############################################################################
#- updateSecretInKeyVault: Update secret in Key Vault
#  arg 1: Key Vault Name
#  arg 2: secret name
#  arg 3: Value
##############################################################################
updateSecretInKeyVault(){
    kv="$1"
    secret="$2"
    value="$3"

    cmd="az keyvault secret set --vault-name \"${kv}\" --name \"${secret}\" --value \"${value}\" --output none"
    # printProgress "${cmd}"
    eval "${cmd}"
    checkError
    # printProgress "${secret}=${value}"
}
##############################################################################
#- readSecretInKeyVault: Read secret from Key Vault
#  arg 1: Key Vault Name
#  arg 2: secret name
##############################################################################
readSecretInKeyVault(){
    kv="$1"
    secret="$2"

    cmd="az keyvault secret show --vault-name \"${kv}\" --name \"${secret}\"  --query \"value\" -o tsv "
    #printProgress "${cmd}"
    eval "${cmd}" 2>/dev/null || true
    #checkError
}
##############################################################################
#- installPreRequisites: Fabric provider, EventHub provider
##############################################################################
installPreRequisites(){
    cmd="az config set extension.dynamic_install_allow_preview=true"
    eval "$cmd" >/dev/null 2>/dev/null || true
    cmd="az provider list --query \"[?namespace=='Microsoft.Fabric'].namespace\" -o tsv"
    NAME=$(eval "$cmd" 2>/dev/null) || true
    if [ -z "$NAME" ] || [ "$NAME" != "Microsoft.Fabric" ]; then
        printProgress "Register Fabric provider"
        cmd="az provider register -n \"Microsoft.Fabric\""
        eval "$cmd" 1>/dev/null
        checkError
    fi
    cmd="az provider list --query \"[?namespace=='Microsoft.EventHub'].namespace\" -o tsv"
    NAME=$(eval "$cmd" 2>/dev/null) || true
    if [ -z "$NAME" ] || [ "$NAME" != "Microsoft.EventHub" ]; then
        printProgress "Register EventHub provider"
        cmd="az provider register -n \"Microsoft.EventHub\""
        eval "$cmd" 1>/dev/null
        checkError
    fi
  
}
##############################################################################
#- installSqlcmd
##############################################################################
installSqlcmd(){
    # 1. Download and install Microsoft's GPG key
    curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc

    # 2. Add the Microsoft SQL Server repository
    # For Ubuntu 22.04 (Jammy)
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

    # For Ubuntu 20.04 (Focal) - use this if above doesn't work
    # curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

    # For Debian (if you're on Debian)
    # curl https://packages.microsoft.com/config/debian/12/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

    # 3. Update package lists
    sudo apt-get update

    # 4. Install mssql-tools (includes sqlcmd and bcp)
    sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev

    # 5. Add sqlcmd to PATH (optional but recommended)
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
    source ~/.bashrc
}
##############################################################################
#- isGuid: Check if the input string is a valid GUID 
##############################################################################
isGuid()
{
    if echo "$1" | grep -qE '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'; then
        echo "true"
    else
        echo "false"
    fi
}
##############################################################################
#- createFabricPostgreSQLManagedPrivateEndpoints 
##############################################################################
createFabricPostgreSQLManagedPrivateEndpoints ()
{
    workspaceName="$1"
    resourceGroup="$2"
    postgresql="$3"
    groupId="postgresqlServer"
    endpointName="mpe-${postgresql}-${groupId}"
    postgresqlResourceId=$(az postgres flexible-server show -n $postgresql  -g $resourceGroup --query id -o tsv)
    token=$(az account get-access-token   --resource https://api.fabric.microsoft.com   --query accessToken -o tsv)
    workspaceId=$(getFabricWorkspaceId $workspaceName)

    printProgress "Creating Managed Private Endpoint: $endpointName"
    ID=$(curl --request GET \
        --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
        --header "Authorization: Bearer $token" \
        --header "Content-Type: application/json" \
         --fail --silent --show-error | jq -r ".value[] | select(.name==\"${endpointName}\") | .id")
    isGuid=$(isGuid "$ID")
    if [ "$isGuid" = "true" ]; then
        printProgress "Managed Private Endpoint: $endpointName already exists with id: $ID"
    else
        printProgress "Creating Managed Private Endpoint: $endpointName "   

        curl --request POST \
            --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
            --header "Authorization: Bearer $token" \
            --header "Content-Type: application/json" \
            --data  "{\"name\": \"${endpointName}\",\"targetPrivateLinkResourceId\": \"${postgresqlResourceId}\",\"targetSubresourceType\": \"${groupId}\",\"requestMessage\": \"Fabric access request for PostgreSQL\"}" \
            --fail --silent --show-error 
        sleep 30
    fi
    for arg in $(az postgres flexible-server show -n ${postgresql}  -g ${resourceGroup} --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].id" -o tsv); do
        printProgress "Approving private Endpoint Connection: $arg"
        az postgres flexible-server private-endpoint-connection approve --id "$arg" --resource-group "$resourceGroup" --description "Approved by Fabric for PostgreSQL access"
    done
}
##############################################################################
#- createFabricCosmosDBManagedPrivateEndpoints 
##############################################################################
createFabricCosmosDBManagedPrivateEndpoints ()
{
    workspaceName="$1"
    resourceGroup="$2"
    cosmosdb="$3"
    groupId="sql"
    endpointName="mpe-${cosmosdb}-${groupId}"
    cosmosdbResourceId=$(az cosmosdb show -n $cosmosdb  -g $resourceGroup --query id -o tsv)
    token=$(az account get-access-token   --resource https://api.fabric.microsoft.com   --query accessToken -o tsv)
    workspaceId=$(getFabricWorkspaceId $workspaceName)

    printProgress "Creating Managed Private Endpoint: $endpointName"
    ID=$(curl --request GET \
        --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
        --header "Authorization: Bearer $token" \
        --header "Content-Type: application/json" \
         --fail --silent --show-error | jq -r ".value[] | select(.name==\"${endpointName}\") | .id")
    isGuid=$(isGuid "$ID")
    if [ "$isGuid" = "true" ]; then
        printProgress "Managed Private Endpoint: $endpointName already exists with id: $ID"
    else
        printProgress "Creating Managed Private Endpoint: $endpointName "   

        curl --request POST \
            --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
            --header "Authorization: Bearer $token" \
            --header "Content-Type: application/json" \
            --data  "{\"name\": \"${endpointName}\",\"targetPrivateLinkResourceId\": \"${cosmosdbResourceId}\",\"targetSubresourceType\": \"${groupId}\",\"requestMessage\": \"Fabric access request for Cosmos DB\"}" \
            --fail --silent --show-error 
        sleep 30
    fi
    for arg in $(az cosmosdb show -n ${cosmosdb}  -g ${resourceGroup} --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].id" -o tsv); do
        printProgress "Approving private Endpoint Connection: $arg"
        az cosmosdb private-endpoint-connection approve --id $arg 
    done

}
##############################################################################
#- createFabricStorageManagedPrivateEndpoints
##############################################################################
createFabricStorageManagedPrivateEndpoints ()
{
    workspaceName="$1"
    resourceGroup="$2"
    storage="$3"
    groupId="blob"
    endpointName="mpe-${storage}-${groupId}"
    storageResourceId=$(az storage account show -n $storage  -g $resourceGroup --query id -o tsv)
    token=$(az account get-access-token   --resource https://api.fabric.microsoft.com   --query accessToken -o tsv)
    workspaceId=$(getFabricWorkspaceId $workspaceName)

    printProgress "Creating Managed Private Endpoint: $endpointName"
    ID=$(curl --request GET \
        --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
        --header "Authorization: Bearer $token" \
        --header "Content-Type: application/json" \
         --fail --silent --show-error | jq -r ".value[] | select(.name==\"${endpointName}\") | .id")
    isGuid=$(isGuid "$ID")
    if [ "$isGuid" = "true" ]; then
        printProgress "Managed Private Endpoint: $endpointName already exists with id: $ID"
    else
        printProgress "Creating Managed Private Endpoint: $endpointName "            
 
        curl --request POST \
            --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
            --header "Authorization: Bearer $token" \
            --header "Content-Type: application/json" \
            --data  "{\"name\": \"${endpointName}\",\"targetPrivateLinkResourceId\": \"${storageResourceId}\",\"targetSubresourceType\": \"${groupId}\",\"requestMessage\": \"Fabric access request for Storage Account\"}" \
            --fail --silent --show-error 
        sleep 30
    fi
    for arg in $(az storage account show -n ${storage}  -g ${resourceGroup} --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].id" -o tsv); do
        printProgress "Approving private Endpoint Connection: $arg"
        az storage account private-endpoint-connection approve --id $arg 
    done
}
##############################################################################
#- createFabricKeyVaultManagedPrivateEndpoints
##############################################################################
createFabricKeyVaultManagedPrivateEndpoints ()
{
    workspaceName="$1"
    resourceGroup="$2"
    keyVault="$3"
    groupId="vault"
    endpointName="mpe-${keyVault}-${groupId}"
    keyVaultResourceId=$(az keyvault show -n $keyVault -g $resourceGroup --query id -o tsv)
    token=$(az account get-access-token   --resource https://api.fabric.microsoft.com   --query accessToken -o tsv)
    workspaceId=$(getFabricWorkspaceId $workspaceName)

    printProgress "Creating Managed Private Endpoint: $endpointName"
    ID=$(curl --request GET \
        --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
        --header "Authorization: Bearer $token" \
        --header "Content-Type: application/json" \
         --fail --silent --show-error | jq -r ".value[] | select(.name==\"${endpointName}\") | .id")
    isGuid=$(isGuid "$ID")
    if [ "$isGuid" = "true" ]; then
        printProgress "Managed Private Endpoint: $endpointName already exists with id: $ID"
    else
        printProgress "Creating Managed Private Endpoint: $endpointName "            

        curl --request POST \
            --url "https://api.fabric.microsoft.com/v1/workspaces/${workspaceId}/managedPrivateEndpoints" \
            --header "Authorization: Bearer $token" \
            --header "Content-Type: application/json" \
            --data  "{\"name\": \"${endpointName}\",\"targetPrivateLinkResourceId\": \"${keyVaultResourceId}\",\"targetSubresourceType\": \"${groupId}\",\"requestMessage\": \"Fabric access request for Key Vault\"}" \
            --fail --silent --show-error 
        sleep 30
    fi
    for arg in $(az keyvault show -n ${keyVault} -g ${resourceGroup}  --query "properties.privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].id" -o tsv); do
        printProgress "Approving private Endpoint Connection: $arg"
        az network private-endpoint-connection approve --id $arg 
    done
}


DEFAULT_ACTION="action not set"
if [ -d "$SCRIPTS_DIRECTORY/../.config" ]; then
    DEFAULT_CONFIGURATION_FILE="$SCRIPTS_DIRECTORY/../.config/.default.env"
else
    DEFAULT_CONFIGURATION_FILE="$SCRIPTS_DIRECTORY/../.default.env"
fi
DEFAULT_ENVIRONMENT="dev"
DEFAULT_REGION="westus3"
DEFAULT_SUBSCRIPTION_ID=""
DEFAULT_TENANT_ID=""
DEFAULT_RESOURCE_GROUP="rg${DEFAULT_ENVIRONMENT}publicfabric"
DEFAULT_POSTGRESQL_ADMIN_USERNAME="sqladmin"
DEFAULT_VM_ADMIN_USERNAME="vmadmin"
DEFAULT_DATAGW_VM_USERNAME="datagwadmin"
ARG_ACTION="${DEFAULT_ACTION}"
ARG_CONFIGURATION_FILE="${DEFAULT_CONFIGURATION_FILE}"
ARG_ENVIRONMENT="${DEFAULT_ENVIRONMENT}"
ARG_REGION="${DEFAULT_REGION}"
ARG_SUBSCRIPTION_ID="${DEFAULT_SUBSCRIPTION_ID}"
ARG_TENANT_ID="${DEFAULT_TENANT_ID}"
ARG_RESOURCE_GROUP="${DEFAULT_RESOURCE_GROUP}"
FABRIC_SKU="F2"
# shellcheck disable=SC2034
while getopts "a:c:e:r:s:t:g:" opt; do
    case $opt in
    a) ARG_ACTION=$OPTARG ;;
    c) ARG_CONFIGURATION_FILE=$OPTARG ;;
    e) ARG_ENVIRONMENT=$OPTARG ;;
    r) ARG_REGION=$OPTARG ;;
    s) ARG_SUBSCRIPTION_ID=$OPTARG ;;
    t) ARG_TENANT_ID=$OPTARG ;;
    g) ARG_RESOURCE_GROUP=$OPTARG ;;
    :)
        echo "Error: -${OPTARG} requires a value"
        exit 1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

if [ $# -eq 0 ] || [ -z "${ARG_ACTION}" ] || [ -z "$ARG_CONFIGURATION_FILE" ]; then
    printError "Required parameters are missing"
    usage
    exit 1
fi
if [ "${ARG_ACTION}" != "deploy-public-fabric" ] && \
   [ "${ARG_ACTION}" != "azure-login" ] && \
   [ "${ARG_ACTION}" != "deploy-public-datasource" ] && \
   [ "${ARG_ACTION}" != "deploy-private-fabric" ] && \
   [ "${ARG_ACTION}" != "remove-public-datasource" ] && \
   [ "${ARG_ACTION}" != "remove-public-fabric" ] && \
   [ "${ARG_ACTION}" != "remove-private-datasource" ] && \
   [ "${ARG_ACTION}" != "remove-private-fabric" ] && \
   [ "${ARG_ACTION}" != "deploy-private-datasource" ]; then
    printError "ACTION '${ARG_ACTION}' not supported, possible values: deploy-public-fabric, deploy-public-datasource, deploy-private-fabric, deploy-private-datasource "
    usage
    exit 1
fi
ACTION=${ARG_ACTION}
CONFIGURATION_FILE=""
if [ -n "${ARG_ENVIRONMENT}" ]; then
    AZURE_ENVIRONMENT="${ARG_ENVIRONMENT}"
fi
# if configuration file exists read subscription id and tenant id values in the file
if [ "$ARG_CONFIGURATION_FILE" ]; then
    if [ -f "$ARG_CONFIGURATION_FILE" ]; then
        readConfigurationFile "$ARG_CONFIGURATION_FILE"
    fi
    CONFIGURATION_FILE=${ARG_CONFIGURATION_FILE}
fi
if [ -n "${ARG_SUBSCRIPTION_ID}" ]; then
    AZURE_SUBSCRIPTION_ID="${ARG_SUBSCRIPTION_ID}"
fi
if [ -n "${ARG_TENANT_ID}" ]; then
    AZURE_TENANT_ID="${ARG_TENANT_ID}"
fi
if [ -n "${ARG_REGION}" ]; then
    AZURE_REGION="${ARG_REGION}"
fi
if [ -n "${ARG_ENVIRONMENT}" ]; then
    AZURE_ENVIRONMENT="${ARG_ENVIRONMENT}"
fi

if [ "${ACTION}" = "azure-login" ] ; then
    printMessage "Azure Login..."
    azLogin
    checkLoginAndSubscription
    printMessage "Azure Login done"
    CURRENT_USER=$(az ad signed-in-user show --query userPrincipalName 2> /dev/null) || true
    CURRENT_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
    CURRENT_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true
    printMessage "You are logged in Azure CLI as user: $CURRENT_USER"
    printMessage "Your current subscription is: $CURRENT_SUBSCRIPTION_ID"
    printMessage "Your current tenant is: $CURRENT_TENANT_ID"
    if [ -f "$CONFIGURATION_FILE" ]; then
        printProgress "Updating configuration file: '${CONFIGURATION_FILE}'..."
        updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_REGION "${AZURE_REGION}"
        updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_SUBSCRIPTION_ID "${AZURE_SUBSCRIPTION_ID}"
        updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_TENANT_ID "${AZURE_TENANT_ID}"
        updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_ENVIRONMENT "${AZURE_ENVIRONMENT}"
    else
        printProgress "Creating a new Azure Configuration file: $CONFIGURATION_FILE..."
        AZURE_SUFFIX="$(getAvailableSuffix ${CURRENT_SUBSCRIPTION_ID})"
        printProgress "Using AZURE_SUFFIX=$AZURE_SUFFIX"
        cat > "$CONFIGURATION_FILE" << EOF
AZURE_REGION="${AZURE_REGION}"
AZURE_SUFFIX=${AZURE_SUFFIX}
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_ENVIRONMENT=${AZURE_ENVIRONMENT}
AZURE_DEFAULT_FABRIC_RESOURCE_GROUP=""
AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP=""
EOF
    fi
    exit 0
fi
printProgress "Checking Azure Configuration..."
checkAzureConfiguration


if [ "${ACTION}" = "deploy-public-fabric" ] ; then
    printProgress "Checking whether the Azure CLI providers and extensions are installed..."
    installPreRequisites
    VISIBILITY="pub"    
    RESOURCE_GROUP_NAME=$(getFabricResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "false" ]; then
        printProgress "Create resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group create -l ${AZURE_REGION} -n ${RESOURCE_GROUP_NAME}"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' already exists"
    fi
    printProgress "call set name ."
    setAzureResourceNames ${AZURE_ENVIRONMENT} "${VISIBILITY}" "${AZURE_SUFFIX}" "${RESOURCE_GROUP_NAME}"

    CLIENT_IP_ADDRESS=$(curl -s https://ifconfig.me)
    OBJECT_ID=$(getCurrentObjectId)
    if [ -z "${OBJECT_ID}" ] || [ "${OBJECT_ID}" = "null" ]; then
        printError "Cannot get current user Object Id"
        exit 1
    fi
    OBJECT_TYPE=$(getCurrentObjectType)
    PRINCIPAL_NAME=$(getCurrentUserPrincipalName)
    if [ -z "${PRINCIPAL_NAME}" ] || [ "${PRINCIPAL_NAME}" = "null" ]; then
        printError "Cannot get current user principal name"
        exit 1
    fi
    printProgress "Deploy public Fabric in resource group '${RESOURCE_GROUP_NAME}'"
    DEFAULT_DEPLOYMENT_PREFIX="${AZURE_ENVIRONMENT}${VISIBILITY}${AZURE_SUFFIX}"
    DEPLOY_NAME=$(date +"fabric${DEFAULT_DEPLOYMENT_PREFIX}-%y%m%d%H%M%S")
    cmd="az deployment group create --resource-group $RESOURCE_GROUP_NAME  --name ${DEPLOY_NAME}   \
    --template-file $SCRIPTS_DIRECTORY/bicep/public-main.bicep \
    --parameters \
    location=${AZURE_REGION} \
    env=${AZURE_ENVIRONMENT} \
    visibility=${VISIBILITY} \
    suffix=${AZURE_SUFFIX} \
    fabricSKU=${FABRIC_SKU} \
    objectId=\"${OBJECT_ID}\" objectType=\"${OBJECT_TYPE}\" principalName=\"${PRINCIPAL_NAME}\"   clientIpAddress=\"${CLIENT_IP_ADDRESS}\"  \
     --verbose"
    printProgress "$cmd"
    eval "$cmd"
    checkError

    if [ -n "${AZURE_FABRIC_WORKSPACE_NAME}" ]; then
        WORKSPACE_ID=$(getFabricWorkspaceId "${AZURE_FABRIC_WORKSPACE_NAME}")
        if [ -z "${WORKSPACE_ID}" ]; then
            printProgress "Creating Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME}"
            createFabricWorkspace "${AZURE_FABRIC_ACCOUNT_NAME}" "${AZURE_FABRIC_WORKSPACE_NAME}" "${FABRIC_SKU}"
            sleep 10
            WORKSPACE_ID=$(getFabricWorkspaceId "${AZURE_FABRIC_WORKSPACE_NAME}")
        fi
        if [ -z "${WORKSPACE_ID}" ]; then
            printError "Cannot get Fabric workspace ID for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
            exit 1
        fi
        printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} id is ${WORKSPACE_ID}"
        WORKSPACE_IDENTITY=$(getFabricWorkspaceIdentity "${WORKSPACE_ID}")
        if [ -z "${WORKSPACE_IDENTITY}" ] || [ "${WORKSPACE_IDENTITY}" = "null" ]; then
            printProgress "Creating Fabric workspace identity for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
            RESULT=$(createFabricWorkspaceIdentity "${WORKSPACE_ID}")
            sleep 10
            WORKSPACE_IDENTITY=$(getFabricWorkspaceIdentity "${WORKSPACE_ID}")
        fi
        if [ -z "${WORKSPACE_IDENTITY}" ] || [ "${WORKSPACE_IDENTITY}" = "null" ]; then
            printError "Cannot get Fabric workspace identity for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
            exit 1
        fi
        printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} and id ${WORKSPACE_ID} has identity ${WORKSPACE_IDENTITY}"
    fi
    updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_FABRIC_WORKSPACE_NAME "${AZURE_FABRIC_WORKSPACE_NAME}"
    updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_FABRIC_WORKSPACE_ID "${WORKSPACE_ID}"
    updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_FABRIC_WORKSPACE_PRINCIPAL_ID "${WORKSPACE_IDENTITY}"
    exit 0
fi

if [ "${ACTION}" = "deploy-public-datasource" ] ; then
    installPreRequisites    
    VISIBILITY="pub"
    RESOURCE_GROUP_NAME=$(getDatasourceResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "false" ]; then
        printProgress "Create resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group create -l ${AZURE_REGION} -n ${RESOURCE_GROUP_NAME}"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        if [ -z "${AZURE_SUFFIX+x}" ] || [ "${AZURE_SUFFIX}" = "" ]; then
            SUFFIX=$(shuf -i 1000-9999 -n 1)
            updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_SUFFIX "${SUFFIX}"
            AZURE_SUFFIX="${SUFFIX}"
        fi
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' already exists"
    fi
    setAzureResourceNames ${AZURE_ENVIRONMENT} "${VISIBILITY}" "${AZURE_SUFFIX}" "${RESOURCE_GROUP_NAME}"
    if [ -z "${AZURE_FABRIC_WORKSPACE_IDENTITY+x}" ] ; then
        if [ -n "${AZURE_FABRIC_WORKSPACE_NAME}" ]; then
            AZURE_FABRIC_WORKSPACE_ID=$(getFabricWorkspaceId "${AZURE_FABRIC_WORKSPACE_NAME}")
            if [ -z "${AZURE_FABRIC_WORKSPACE_ID}" ]; then
                printError "Cannot get Fabric workspace ID for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
                exit 1
            fi
            printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} id is ${AZURE_FABRIC_WORKSPACE_ID}"
            AZURE_FABRIC_WORKSPACE_IDENTITY=$(getFabricWorkspaceIdentity "${AZURE_FABRIC_WORKSPACE_ID}")
            if [ -z "${AZURE_FABRIC_WORKSPACE_IDENTITY}" ] || [ "${AZURE_FABRIC_WORKSPACE_IDENTITY}" = "null" ]; then
                printError "Cannot get Fabric workspace identity for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
                exit 1
            fi
            printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} and id ${AZURE_FABRIC_WORKSPACE_ID} has identity ${AZURE_FABRIC_WORKSPACE_IDENTITY}"
        fi
    fi


    CLIENT_IP_ADDRESS=$(curl -s https://ifconfig.me)
    OBJECT_ID=$(getCurrentObjectId)
    OBJECT_TYPE=$(getCurrentObjectType)

    printProgress "Reading SQL Administrator login from Key Vault  ${AZURE_KEY_VAULT_NAME}"
    POSTGRESQL_ADMIN_LOGIN=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_LOGIN_SECRET_NAME}")
    if [ -z "${POSTGRESQL_ADMIN_LOGIN}" ]; then
        printProgress "Writing SQL Administrator login to Key Vault  ${AZURE_KEY_VAULT_NAME}"
        POSTGRESQL_ADMIN_LOGIN="${DEFAULT_POSTGRESQL_ADMIN_USERNAME}"
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_LOGIN_SECRET_NAME}" "${POSTGRESQL_ADMIN_LOGIN}"
    else
        printProgress "Using existing SQL Administrator login from Key Vault  ${AZURE_KEY_VAULT_NAME}"
    fi
    printProgress "Reading PostgreSQL Administrator password from Key Vault  ${AZURE_KEY_VAULT_NAME}"
    POSTGRESQL_ADMIN_PASSWORD=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_PASSWORD_SECRET_NAME}")
    if [ -z "${POSTGRESQL_ADMIN_PASSWORD}" ]; then
        printProgress "Generating and storing PostgreSQL Administrator password in Key Vault  ${AZURE_KEY_VAULT_NAME}"
        POSTGRESQL_ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 12)$(tr -dc '[:upper:]' < /dev/urandom  | head -c1)$(tr -dc '[:lower:]' < /dev/urandom  | head -c1)$(tr -dc '0-9' < /dev/urandom  | head -c1)
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_PASSWORD_SECRET_NAME}" "${POSTGRESQL_ADMIN_PASSWORD}"
    fi

    printProgress "Deploy public datasource in resource group '${RESOURCE_GROUP_NAME}'"
    DEFAULT_DEPLOYMENT_PREFIX="${AZURE_ENVIRONMENT}${VISIBILITY}${AZURE_SUFFIX}"
    DEPLOY_NAME=$(date +"datasource${DEFAULT_DEPLOYMENT_PREFIX}-%y%m%d%H%M%S")
    cmd="az deployment group create --resource-group $RESOURCE_GROUP_NAME \
    --name "${DEPLOY_NAME}" --template-file $SCRIPTS_DIRECTORY/bicep/public-datasource.bicep \
    --parameters  \
    location=${AZURE_REGION} \
    env=${AZURE_ENVIRONMENT} \
    visibility=${VISIBILITY} \
    suffix=${AZURE_SUFFIX} \
    sqlAdministratorLogin=\"${POSTGRESQL_ADMIN_LOGIN}\" \
    sqlAdministratorPassword=\"${POSTGRESQL_ADMIN_PASSWORD}\" \
    fabricPrincipalId=\"${AZURE_FABRIC_WORKSPACE_IDENTITY}\" \
    objectId=\"${OBJECT_ID}\"  objectType=\"${OBJECT_TYPE}\"  \
    clientIpAddress=\"${CLIENT_IP_ADDRESS}\"  --verbose"
    printProgress "$cmd"
    eval "$cmd"
    checkError

    printProgress "Upload dataset in storage account '${AZURE_STORAGE_ACCOUNT_NAME}' under container '${AZURE_STORAGE_ACCOUNT_DEFAULT_CONTAINER_NAME}'"
    cmd="az storage blob upload-batch --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --destination ${AZURE_STORAGE_ACCOUNT_DEFAULT_CONTAINER_NAME} --source $SCRIPTS_DIRECTORY/data/samples --overwrite --auth-mode login"
    printProgress "$cmd"
    eval "$cmd"

    SQLCMD_PATH=$(command -v sqlcmd 2>/dev/null)
    printProgress "Checking if sqlcmd is installed"
    if [ ! -n "$SQLCMD_PATH" ]; then
        printProgress "Installing sqlcmd"
        installSqlcmd
    fi
    printProgress "Creating Product table 'Product' in PostgreSQL  database '$AZURE_POSTGRESQL_NAME'"
    POSTGRESQL_DATABASE="products"
    cmd="PGPASSWORD=$POSTGRESQL_ADMIN_PASSWORD  \
        psql \
            -h \"$AZURE_POSTGRESQL_NAME.postgres.database.azure.com\" \
            -U \"$POSTGRESQL_ADMIN_LOGIN\" \
            -d \"postgres\" \
            -c \"CREATE DATABASE $POSTGRESQL_DATABASE;\""
    #printProgress "$cmd"
    eval "$cmd"

    cmd="PGPASSWORD=$POSTGRESQL_ADMIN_PASSWORD  \
            psql \
            -h \"$AZURE_POSTGRESQL_NAME.postgres.database.azure.com\" \
            -U \"$POSTGRESQL_ADMIN_LOGIN\" \
            -d \"$POSTGRESQL_DATABASE\" \
            -v ON_ERROR_STOP=1 \
            -f \"$SCRIPTS_DIRECTORY/data/products/setup.sql\""
    
    #printProgress "$cmd"
    eval "$cmd"

    exit 0
fi

if [ "${ACTION}" = "deploy-private-fabric" ] ; then
    printProgress "Checking whether the Azure CLI providers and extensions are installed..."
    installPreRequisites
    VISIBILITY="pri"
    RESOURCE_GROUP_NAME=$(getFabricResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "false" ]; then
        printProgress "Create resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group create -l ${AZURE_REGION} -n ${RESOURCE_GROUP_NAME}"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        if [ -z "${AZURE_SUFFIX+x}" ] || [ "${AZURE_SUFFIX}" = "" ]; then
            SUFFIX=$(shuf -i 1000-9999 -n 1)
            updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_SUFFIX "${SUFFIX}"
            AZURE_SUFFIX="${SUFFIX}"
        fi
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' already exists"
    fi
    setAzureResourceNames ${AZURE_ENVIRONMENT} "${VISIBILITY}" "${AZURE_SUFFIX}" "${RESOURCE_GROUP_NAME}"
    printProgress "Deploy private Fabric in resource group '${RESOURCE_GROUP_NAME}'"

    OBJECT_ID=$(getCurrentObjectId)
    if [ -z "${OBJECT_ID}" ] || [ "${OBJECT_ID}" = "null" ]; then
        printError "Cannot get current user Object Id"
        exit 1
    fi    
    OBJECT_TYPE=$(getCurrentObjectType)
    PRINCIPAL_NAME=$(getCurrentUserPrincipalName)
    if [ -z "${PRINCIPAL_NAME}" ] || [ "${PRINCIPAL_NAME}" = "null" ]; then
        printError "Cannot get current user principal name"
        exit 1
    fi    
    DEFAULT_DEPLOYMENT_PREFIX="${AZURE_ENVIRONMENT}${VISIBILITY}${AZURE_SUFFIX}"
    DEPLOY_NAME=$(date +"fabric${DEFAULT_DEPLOYMENT_PREFIX}-%y%m%d%H%M%S")
    cmd="az deployment group create --resource-group $RESOURCE_GROUP_NAME --name ${DEPLOY_NAME} \
    --template-file $SCRIPTS_DIRECTORY/bicep/private-main.bicep \
    --parameters \
    location=${AZURE_REGION} \
    env=${AZURE_ENVIRONMENT} \
    visibility=${VISIBILITY} \
    suffix=${AZURE_SUFFIX} \
    fabricSKU=${FABRIC_SKU} \
    vnetAddressPrefix=\"10.13.0.0/16\" \
    privateEndpointSubnetAddressPrefix=\"10.13.0.0/24\" \
    bastionSubnetAddressPrefix=\"10.13.1.0/24\" \
    datagwSubnetAddressPrefix=\"10.13.2.0/24\" \
    gatewaySubnetAddressPrefix=\"10.13.3.0/24\" \
    dnsDelegationSubnetAddressPrefix=\"10.13.4.0/24\" \
    dnsDelegationSubnetIPAddress=\"10.13.4.22\" \
    dnsZoneResourceGroupName=\"${RESOURCE_GROUP_NAME}\" \
    dnsZoneSubscriptionId=\"${AZURE_SUBSCRIPTION_ID}\" \
    newOrExistingDnsZones=\"new\" \
    objectId=\"${OBJECT_ID}\"  objectType=\"${OBJECT_TYPE}\" principalName=\"${PRINCIPAL_NAME}\"  \
     --verbose"
    printProgress "$cmd"
    eval "$cmd"
    checkError

    if [ -n "${AZURE_FABRIC_WORKSPACE_NAME}" ]; then
        WORKSPACE_ID=$(getFabricWorkspaceId "${AZURE_FABRIC_WORKSPACE_NAME}")
        if [ -z "${WORKSPACE_ID}" ]; then
            printProgress "Creating Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME}"
            createFabricWorkspace "${AZURE_FABRIC_ACCOUNT_NAME}" "${AZURE_FABRIC_WORKSPACE_NAME}" "${FABRIC_SKU}"
            sleep 10
            WORKSPACE_ID=$(getFabricWorkspaceId "${AZURE_FABRIC_WORKSPACE_NAME}")
        fi
        if [ -z "${WORKSPACE_ID}" ]; then
            printError "Cannot get Fabric workspace ID for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
            exit 1
        fi
        printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} id is ${WORKSPACE_ID}"
        WORKSPACE_IDENTITY=$(getFabricWorkspaceIdentity "${WORKSPACE_ID}")
        if [ -z "${WORKSPACE_IDENTITY}" ] || [ "${WORKSPACE_IDENTITY}" = "null" ]; then
            printProgress "Creating Fabric workspace identity for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
            RESULT=$(createFabricWorkspaceIdentity "${WORKSPACE_ID}")
            sleep 10
            WORKSPACE_IDENTITY=$(getFabricWorkspaceIdentity "${WORKSPACE_ID}")
        fi
        if [ -z "${WORKSPACE_IDENTITY}" ] || [ "${WORKSPACE_IDENTITY}" = "null" ]; then
            printError "Cannot get Fabric workspace identity for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
            exit 1
        fi
        printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} and id ${WORKSPACE_ID} has identity ${WORKSPACE_IDENTITY}"
    fi

    updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_FABRIC_WORKSPACE_NAME "${AZURE_FABRIC_WORKSPACE_NAME}"
    updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_FABRIC_WORKSPACE_ID "${WORKSPACE_ID}"
    updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_FABRIC_WORKSPACE_PRINCIPAL_ID "${WORKSPACE_IDENTITY}"
    exit 0
fi

if [ "${ACTION}" = "deploy-private-datasource" ] ; then
    installPreRequisites
    VISIBILITY="pri"
    RESOURCE_GROUP_NAME=$(getDatasourceResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "false" ]; then
        printProgress "Create resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group create -l ${AZURE_REGION} -n ${RESOURCE_GROUP_NAME}"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        if [ -z "${AZURE_SUFFIX+x}" ] || [ "${AZURE_SUFFIX}" = "" ]; then
            SUFFIX=$(shuf -i 1000-9999 -n 1)
            updateConfigurationFile "${CONFIGURATION_FILE}" AZURE_SUFFIX "${SUFFIX}"
            AZURE_SUFFIX="${SUFFIX}"
        fi
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' already exists"
    fi
    setAzureResourceNames ${AZURE_ENVIRONMENT} "${VISIBILITY}" "${AZURE_SUFFIX}" "${RESOURCE_GROUP_NAME}"

    if [ -z "${AZURE_FABRIC_WORKSPACE_IDENTITY+x}" ] ; then
        if [ -n "${AZURE_FABRIC_WORKSPACE_NAME}" ]; then
            AZURE_FABRIC_WORKSPACE_ID=$(getFabricWorkspaceId "${AZURE_FABRIC_WORKSPACE_NAME}")
            if [ -z "${AZURE_FABRIC_WORKSPACE_ID}" ]; then
                printError "Cannot get Fabric workspace ID for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
                exit 1
            fi
            printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} id is ${AZURE_FABRIC_WORKSPACE_ID}"
            AZURE_FABRIC_WORKSPACE_IDENTITY=$(getFabricWorkspaceIdentity "${AZURE_FABRIC_WORKSPACE_ID}")
            if [ -z "${AZURE_FABRIC_WORKSPACE_IDENTITY}" ] || [ "${AZURE_FABRIC_WORKSPACE_IDENTITY}" = "null" ]; then
                printError "Cannot get Fabric workspace identity for workspace name ${AZURE_FABRIC_WORKSPACE_NAME}"
                exit 1
            fi
            printProgress "Fabric workspace with name ${AZURE_FABRIC_WORKSPACE_NAME} and id ${AZURE_FABRIC_WORKSPACE_ID} has identity ${AZURE_FABRIC_WORKSPACE_IDENTITY}"
        fi
    fi

    CLIENT_IP_ADDRESS=$(curl -s https://ifconfig.me)
    OBJECT_ID=$(getCurrentObjectId)
    OBJECT_TYPE=$(getCurrentObjectType)

    POSTGRESQL_ADMIN_LOGIN=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_LOGIN_SECRET_NAME}")
    if [ -z "${POSTGRESQL_ADMIN_LOGIN}" ]; then
        POSTGRESQL_ADMIN_LOGIN="${DEFAULT_POSTGRESQL_ADMIN_USERNAME}"
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_LOGIN_SECRET_NAME}" "${POSTGRESQL_ADMIN_LOGIN}"
    else
        printProgress "Using existing PostgreSQL SQL Administrator login from Key Vault  ${AZURE_KEY_VAULT_NAME}"
    fi
    POSTGRESQL_ADMIN_PASSWORD=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_PASSWORD_SECRET_NAME}")
    if [ -z "${POSTGRESQL_ADMIN_PASSWORD}" ]; then
        printProgress "Generating and storing PostgreSQL SQL Administrator password in Key Vault  ${AZURE_KEY_VAULT_NAME}"
        POSTGRESQL_ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 12)$(tr -dc '[:upper:]' < /dev/urandom  | head -c1)$(tr -dc '[:lower:]' < /dev/urandom  | head -c1)$(tr -dc '0-9' < /dev/urandom  | head -c1)
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_POSTGRESQL_ADMINISTRATOR_PASSWORD_SECRET_NAME}" "${POSTGRESQL_ADMIN_PASSWORD}"
    fi

    FABRIC_RESOURCE_GROUP_NAME=$(getFabricResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")


    DATAGW_VM_SKU_NAME="Standard_B2ms"
    DATA_GATEWAY_LOGIN=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_VM_LOGIN_SECRET_NAME}")
    if [ -z "${DATA_GATEWAY_LOGIN}" ]; then
        DATA_GATEWAY_LOGIN="${DEFAULT_DATAGW_VM_USERNAME}"
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_VM_LOGIN_SECRET_NAME}" "${DATA_GATEWAY_LOGIN}"
    else
        printProgress "Using existing Data Gateway login from Key Vault  ${AZURE_KEY_VAULT_NAME}"
    fi
    DATA_GATEWAY_PASSWORD=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_VM_PASSWORD_SECRET_NAME}")
    if [ -z "${DATA_GATEWAY_PASSWORD}" ]; then
        printProgress "Generating and storing Data Gateway password in Key Vault  ${AZURE_KEY_VAULT_NAME}"
        DATA_GATEWAY_PASSWORD=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 12)$(tr -dc '[:upper:]' < /dev/urandom  | head -c1)$(tr -dc '[:lower:]' < /dev/urandom  | head -c1)$(tr -dc '0-9' < /dev/urandom  | head -c1)
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_VM_PASSWORD_SECRET_NAME}" "${DATA_GATEWAY_PASSWORD}"
    fi
    DATA_GATEWAY_RECOVERY_KEY=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_VM_RECOVERY_KEY_SECRET_NAME}")
    if [ -z "${DATA_GATEWAY_RECOVERY_KEY}" ]; then
        printProgress "Generating and storing Data Gateway recovery key in Key Vault  ${AZURE_KEY_VAULT_NAME}"
        DATA_GATEWAY_RECOVERY_KEY=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 12)$(tr -dc '[:upper:]' < /dev/urandom  | head -c1)$(tr -dc '[:lower:]' < /dev/urandom  | head -c1)$(tr -dc '0-9' < /dev/urandom  | head -c1)
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_VM_RECOVERY_KEY_SECRET_NAME}" "${DATA_GATEWAY_RECOVERY_KEY}"
    fi

    DATA_GATEWAY_CERTIFICATE_PASSWORD=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_CERTIFICATE_PASSWORD_SECRET_NAME}")
    if [ -z "${DATA_GATEWAY_CERTIFICATE_PASSWORD}" ]; then
        printProgress "Generating and storing Data Gateway certificate password in Key Vault  ${AZURE_KEY_VAULT_NAME}"
        DATA_GATEWAY_CERTIFICATE_PASSWORD=$(openssl rand -base64 32)
        updateSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_CERTIFICATE_PASSWORD_SECRET_NAME}" "${DATA_GATEWAY_CERTIFICATE_PASSWORD}"
    fi

    DATA_GATEWAY_CERTIFICATE=$(readSecretInKeyVault "${AZURE_KEY_VAULT_NAME}" "${AZURE_DATAGW_CERTIFICATE_SECRET_NAME}")
    if [ -z "${DATA_GATEWAY_CERTIFICATE}" ]; then
        printProgress "Generating and storing Data Gateway certificate in Key Vault  ${AZURE_KEY_VAULT_NAME}"
        DAYS=730
        # private key
        printProgress "Creating private key for Data Gateway certificate"
        openssl genrsa -out ${AZURE_DATAGW_CERTIFICATE_NAME}.key 2048
        # self-signed certificate
        printProgress "Creating self-signed certificate for Data Gateway"
        openssl req -new -x509 \
        -key ${AZURE_DATAGW_CERTIFICATE_NAME}.key \
        -out ${AZURE_DATAGW_CERTIFICATE_NAME}.crt \
        -days $DAYS \
        -subj "/CN=${AZURE_DATAGW_CERTIFICATE_NAME}"
        printProgress "Creating pfx file for Data Gateway certificate"
        openssl pkcs12 -export \
        -out ${AZURE_DATAGW_CERTIFICATE_NAME}.pfx \
        -inkey ${AZURE_DATAGW_CERTIFICATE_NAME}.key \
        -in ${AZURE_DATAGW_CERTIFICATE_NAME}.crt \
        -password pass:$DATA_GATEWAY_CERTIFICATE_PASSWORD
        printProgress "Importing pfx file for Data Gateway certificate in key vault ${AZURE_KEY_VAULT_NAME}"
        az keyvault certificate import \
        --vault-name ${AZURE_KEY_VAULT_NAME} \
        --name ${AZURE_DATAGW_CERTIFICATE_SECRET_NAME} \
        --file ${AZURE_DATAGW_CERTIFICATE_NAME}.pfx \
        --password $DATA_GATEWAY_CERTIFICATE_PASSWORD
    fi

    APP_ID=$(az ad app list --display-name ${AZURE_DATAGW_APP_NAME}  --all --query [0].appId -o tsv)
    if [ -z "${APP_ID}" ]; then
        printProgress "Creating application for Data Gateway"
        APP_ID=$(az ad app create \
        --display-name $AZURE_DATAGW_APP_NAME \
        --query appId -o tsv)
        printProgress "Associating application for Data Gateway with certificate ${AZURE_DATAGW_CERTIFICATE_NAME}.crt"
        az ad app credential reset \
        --id $APP_ID \
        --cert @${AZURE_DATAGW_CERTIFICATE_NAME}.crt

        printProgress "Add permission to use Power BI application for Data Gateway"
        POWERBI_APP_ID=00000009-0000-0000-c000-000000000000
        az ad app permission add \
        --id $APP_ID \
        --api $POWERBI_APP_ID \
        --api-permissions \
            654b31ae-d941-4e22-8798-7add8fdf049f=Role \
            28379fa9-8596-4fd9-869e-cb60a93b5d84=Role

        printProgress "Create admin consent for application"
        # az ad app permission grant --id $APP_ID --api $POWERBI_APP_ID
        az ad app permission admin-consent --id $APP_ID
    fi

    printProgress "Deploy private datasource in resource group '${RESOURCE_GROUP_NAME}'"
    cmd="az deployment group create --resource-group $RESOURCE_GROUP_NAME \
    --template-file $SCRIPTS_DIRECTORY/bicep/private-datasource.bicep \
    --parameters  \
    location=${AZURE_REGION} \
    env=${AZURE_ENVIRONMENT} \
    visibility=${VISIBILITY} \
    suffix=${AZURE_SUFFIX} \
    dnsZoneSubscriptionId=\"${AZURE_SUBSCRIPTION_ID}\" \
    newOrExistingDnsZones=\"existing\" \
    dnsZoneResourceGroupName=\"${FABRIC_RESOURCE_GROUP_NAME}\" \
    sqlAdministratorLogin=\"${POSTGRESQL_ADMIN_LOGIN}\" \
    sqlAdministratorPassword=\"${POSTGRESQL_ADMIN_PASSWORD}\" \
    vmSkuName=\"${DATAGW_VM_SKU_NAME}\" \
    administratorUsername=\"${DATA_GATEWAY_LOGIN}\" \
    administratorPassword=\"${DATA_GATEWAY_PASSWORD}\" \
    recoveryKey=\"${DATA_GATEWAY_RECOVERY_KEY}\" \
    fabricPrincipalId=\"${AZURE_FABRIC_WORKSPACE_IDENTITY}\" \
    objectId=\"${OBJECT_ID}\"  objectType=\"${OBJECT_TYPE}\"  \
    clientIpAddress=\"${CLIENT_IP_ADDRESS}\"  appId=\"${APP_ID}\" --verbose"
    printProgress "$cmd"
    eval "$cmd"
    checkError

    printProgress "Updating storage account '${AZURE_STORAGE_ACCOUNT_NAME}'  firewall configuration to allow access from all networks"
    # cmd="az storage account update  --default-action Allow --resource-group "${RESOURCE_GROUP_NAME}" --name "${AZURE_STORAGE_ACCOUNT_NAME}""
    cmd="az storage account update \
    --name ${AZURE_STORAGE_ACCOUNT_NAME} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --public-network-access Enabled"

    printProgress "$cmd"
    eval "$cmd" >/dev/null
    sleep 30

    printProgress "Upload dataset in storage account '${AZURE_STORAGE_ACCOUNT_NAME}' under container '${AZURE_STORAGE_ACCOUNT_DEFAULT_CONTAINER_NAME}'"
    cmd="az storage blob upload-batch --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --destination ${AZURE_STORAGE_ACCOUNT_DEFAULT_CONTAINER_NAME} --source $SCRIPTS_DIRECTORY/data/samples --overwrite --auth-mode login"
    printProgress "$cmd"
    eval "$cmd"

    printProgress "Updating storage account '${AZURE_STORAGE_ACCOUNT_NAME}'  firewall configuration to block access from all networks"
    cmd="az storage account update \
    --name ${AZURE_STORAGE_ACCOUNT_NAME} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --public-network-access Disabled"
    printProgress "$cmd"
    eval "$cmd" >/dev/null
    sleep 30

    printProgress "Creating Product table 'Product' in PostgreSQL  database '$AZURE_POSTGRESQL_NAME'"
    POSTGRESQL_DATABASE="products"
    cmd="PGPASSWORD=$POSTGRESQL_ADMIN_PASSWORD  \
        psql \
            -h \"$AZURE_POSTGRESQL_NAME.postgres.database.azure.com\" \
            -U \"$POSTGRESQL_ADMIN_LOGIN\" \
            -d \"postgres\" \
            -c \"CREATE DATABASE $POSTGRESQL_DATABASE;\""
    #printProgress "$cmd"
    eval "$cmd"

    cmd="PGPASSWORD=$POSTGRESQL_ADMIN_PASSWORD  \
            psql \
            -h \"$AZURE_POSTGRESQL_NAME.postgres.database.azure.com\" \
            -U \"$POSTGRESQL_ADMIN_LOGIN\" \
            -d \"$POSTGRESQL_DATABASE\" \
            -v ON_ERROR_STOP=1 \
            -f \"$SCRIPTS_DIRECTORY/data/products/setup.sql\""
    
    #printProgress "$cmd"
    eval "$cmd"


    
    printProgress "Creating Managed Private Endpoints for Fabric Workspace ${AZURE_FABRIC_WORKSPACE_NAME}"
    createFabricKeyVaultManagedPrivateEndpoints "${AZURE_FABRIC_WORKSPACE_NAME}" "${AZURE_RESOURCE_GROUP_FABRIC_NAME}" "${AZURE_KEY_VAULT_NAME}"
    createFabricStorageManagedPrivateEndpoints "${AZURE_FABRIC_WORKSPACE_NAME}" "${AZURE_RESOURCE_GROUP_DATASOURCE_NAME}" "${AZURE_STORAGE_ACCOUNT_NAME}" 
    createFabricPostgreSQLManagedPrivateEndpoints "${AZURE_FABRIC_WORKSPACE_NAME}" "${AZURE_RESOURCE_GROUP_DATASOURCE_NAME}" "${AZURE_POSTGRESQL_NAME}"
    createFabricCosmosDBManagedPrivateEndpoints "${AZURE_FABRIC_WORKSPACE_NAME}" "${AZURE_RESOURCE_GROUP_DATASOURCE_NAME}" "${AZURE_COSMOS_DB_NAME}"
    
    exit 0
fi




if [ "${ACTION}" = "remove-public-fabric" ] ; then
    VISIBILITY="pub"
    RESOURCE_GROUP_NAME=$(getFabricResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "true" ]; then
        printProgress "Remove resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group delete  -n ${RESOURCE_GROUP_NAME} -y"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' doesn't exists"
    fi
    exit 0
fi

if [ "${ACTION}" = "remove-public-datasource" ] ; then
    VISIBILITY="pub"
    RESOURCE_GROUP_NAME=$(getDatasourceResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "true" ]; then
        printProgress "Remove resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group delete  -n ${RESOURCE_GROUP_NAME} -y"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' doesn't exists"
    fi
    exit 0
fi

if [ "${ACTION}" = "remove-private-fabric" ] ; then
    VISIBILITY="pri"
    RESOURCE_GROUP_NAME=$(getFabricResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "true" ]; then
        printProgress "Remove resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group delete  -n ${RESOURCE_GROUP_NAME} -y"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' doesn't exists"
    fi
    exit 0
fi

if [ "${ACTION}" = "remove-private-datasource" ] ; then
    VISIBILITY="pri"
    RESOURCE_GROUP_NAME=$(getDatasourceResourceGroupName "${AZURE_ENVIRONMENT}" "${VISIBILITY}" "${AZURE_SUFFIX}")
    if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "true" ]; then
        printProgress "Remove resource group  '${RESOURCE_GROUP_NAME}' in location '${AZURE_REGION}'"
        cmd="az group delete  -n ${RESOURCE_GROUP_NAME} -y"
        printProgress "$cmd"
        eval "$cmd" 1>/dev/null
        checkError
    else
        printProgress "Resource group '${RESOURCE_GROUP_NAME}' doesn't exists"
    fi
    exit 0
fi
