#!/bin/sh
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
    printf " --storage-account  Sets the Azure Storage account name\n"
    printf " --container  Sets the Azure Storage container name\n"
    echo
    echo "Example:"
    printf " bash ./deploy-generic-data.sh --storage-account sastoragedev --container my-container \n"
}
SCRIPTS_DIRECTORY=$(dirname "$0")
ARG_STORAGE_ACCOUNT=""
ARG_CONTAINER=""
STORAGE_FOLDER="generic"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --storage-account)
            ARG_STORAGE_ACCOUNT="$2"
            shift 2
            ;;
        --container)
            ARG_CONTAINER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done


if [ -z "$ARG_STORAGE_ACCOUNT" ]; then
  printError "Azure Storage account name not provided."
  usage
  exit 1
fi
if [ -z "$ARG_CONTAINER" ]; then
  printError "Azure Storage container name not provided."
  usage
  exit 1
fi
printProgress "Using Azure Storage account: $ARG_STORAGE_ACCOUNT"
printProgress "Using Azure Storage container: $ARG_CONTAINER"

RESULT=$(az storage container show --name "${ARG_CONTAINER}" --account-name "${ARG_STORAGE_ACCOUNT}" --auth-mode login --query name -o tsv 2>/dev/null || true)
if [ ! -z "$RESULT" ] && [ "$RESULT" = "${ARG_CONTAINER}" ]; then
  printProgress "Container ${ARG_CONTAINER} already exists."
else
  printProgress "Creating container ${ARG_CONTAINER}."
  az storage container create \
    --name "${ARG_CONTAINER}" \
    --account-name "${ARG_STORAGE_ACCOUNT}" \
    --auth-mode login
  checkError
fi

printProgress "Uploading files under '$SCRIPTS_DIRECTORY/data/generic' on  'https://${ARG_STORAGE_ACCOUNT}.dfs.core.windows.net/${ARG_CONTAINER}/${STORAGE_FOLDER}'"
az storage blob upload-batch --account-name "${ARG_STORAGE_ACCOUNT}" --destination "${ARG_CONTAINER}" --destination-path "${STORAGE_FOLDER}" --source "$SCRIPTS_DIRECTORY/data/generic" --overwrite --auth-mode login
checkError
printProgress "Upload successful"
