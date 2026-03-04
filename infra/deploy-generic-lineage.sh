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
    printf " --fabric-account  Sets the Azure Storage account name\n"
    printf " --storage-account  Sets the Azure Storage account name\n"
    printf " --container  Sets the Azure Storage container name\n"
    echo
    echo "Example:"
    printf " bash ./deploy-generic-lineage.sh --fabric-account my-fabric-account --storage-account mystorage --container my-container \n"
}
SCRIPTS_DIRECTORY=$(dirname "$0")
ARG_PURVIEW_ACCOUNT=""
ARG_STORAGE_ACCOUNT=""
ARG_CONTAINER=""
STORAGE_FOLDER=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --fabric-account)
            ARG_PURVIEW_ACCOUNT="$2"
            shift 2
            ;;
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
if [ -z "$ARG_PURVIEW_ACCOUNT" ]; then
  printError "Azure Fabric account name not provided."
  usage
  exit 1
fi
if [ -z "$ARG_CONTAINER" ]; then
  printError "Azure Storage container name not provided."
  usage
  exit 1
fi
printProgress "Using Azure Fabric account: $ARG_PURVIEW_ACCOUNT"
printProgress "Using Azure Storage account: $ARG_STORAGE_ACCOUNT"
printProgress "Using Azure Storage container: $ARG_CONTAINER"
python "$SCRIPTS_DIRECTORY/lineage_generic.py" --fabric-account "$ARG_PURVIEW_ACCOUNT" --storage-account "$ARG_STORAGE_ACCOUNT" --container "$ARG_CONTAINER"
printProgress "Creation successful"
