# Deploying Fabric with data sources

## Introduction

This document describe how to deploy Microsoft Fabric and sample data sources based Azure Storage Account ADLS gen2.
Once the infrastructure is deployed, you can evaluate Microsoft Fabric running different scenarios:
- Scanning
- Classification
- Lineage

Moreover, as it's an evaluation of the Fabric infrastructure, it supports both configurations:
- One configuration with public endpoints to reach Fabric and data sources.
- One configuration with private endpoints to reach Fabric and data sources.

## Getting Started

In this repository, you'll find scripts and bicep files to deploy a Fabric Infrastructure. This infrastructure will be deployed in the cloud (Azure)<>

This chapter describes how to :

1. Install the pre-requisites including Visual Studio Code, Dev Container
2. Create, deploy the infrastructure

This repository contains the following resources :

- A Dev container under '.devcontainer' folder
- The Azure configuration for a deployment under '.config' folder
- The scripts, bicep files and dataset files used to deploy the infrastructure under: ./infra

### Installing the pre-requisites

In order to test the solution, you need first an Azure Subscription, you can get further information about Azure Subscription [here](https://azure.microsoft.com/en-us/free).

You also need to install Git client and Visual Studio Code on your machine, below the links.

|[![Windows](./windows_logo.png)](https://git-scm.com/download/win) |[![Linux](./linux_logo.png)](https://git-scm.com/download/linux)|[![MacOS](./macos_logo.png)](https://git-scm.com/download/mac)|
|:---|:---|:---|
| [Git Client for Windows](https://git-scm.com/download/win) | [Git client for Linux](https://git-scm.com/download/linux)| [Git Client for MacOs](https://git-scm.com/download/mac) |
[Visual Studio Code for Windows](https://code.visualstudio.com/Download)  | [Visual Studio Code for Linux](https://code.visualstudio.com/Download)  &nbsp;| [Visual Studio Code for MacOS](https://code.visualstudio.com/Download) &nbsp; &nbsp;|

Once the Git client is installed you can clone the repository on your machine running the following commands:

1. Create a Git directory on your machine

    ```bash
        c:\> mkdir git
        c:\> cd git
        c:\git>
    ```

2. Clone the repository.
    For instance:

    ```bash
        c:\git> git clone  https://github.com/flecoqui/fabric-automated.git
        c:\git> cd ./fabric-automated
        c:\git\fabric-automated>
    ```

### Using Dev Container

#### Installing Dev Container pre-requisites

You need to install the following pre-requisite on your machine

1. Install and configure [Docker](https://www.docker.com/get-started) for your operating system.

   - Windows / macOS:

     1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop) for Windows/Mac.

     2. Right-click on the Docker task bar item, select Settings / Preferences and update Resources > File Sharing with any locations your source code is kept. See [tips and tricks](https://code.visualstudio.com/docs/remote/troubleshooting#_container-tips) for troubleshooting.

     3. If you are using WSL 2 on Windows, to enable the [Windows WSL 2 back-end](https://docs.docker.com/docker-for-windows/wsl/): Right-click on the Docker taskbar item and select Settings. Check Use the WSL 2 based engine and verify your distribution is enabled under Resources > WSL Integration.

   - Linux:

     1. Follow the official install [instructions for Docker CE/EE for your distribution](https://docs.docker.com/get-docker/). If you are using Docker Compose, follow the [Docker Compose directions](https://docs.docker.com/compose/install/) as well.

     2. Add your user to the docker group by using a terminal to run: 'sudo usermod -aG docker $USER'

     3. Sign out and back in again so your changes take effect.

2. Ensure [Visual Studio Code](https://code.visualstudio.com/) is already installed.

3. Install the [Remote Development extension pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

#### Using Visual Studio Code and Dev Container

1. Launch Visual Studio Code in the folder where you cloned the 'ps-data-foundation-imv' repository

    ```bash
        c:\git\dataops> code .
    ```

2. Once Visual Studio Code is launched, you should see the following dialog box:

    ![Visual Studio Code](./reopen-in-container.png)

3. Click on the button 'Reopen in Container'
4. Visual Studio Code opens the Dev Container. If it's the first time you open the project in container mode, it first builds the container, it can take several minutes to build the new container.
5. Once the container is loaded, you can open a new terminal (Terminal -> New Terminal).
6. And from the terminal, you have access to the tools installed in the Dev Container like az client,....

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ az login
    ```

### How to deploy infrastructure from the Dev Container terminal

The Dev Container is now running, you can use the bash file [./infra/deploy-infra.sh ](../../infra/deploy-infra.sh ) to:

- deploy the infrastructure 
- trigger datasource scanning
- trigger custom lineage creation

Below the list of arguments associated with 'deploy-infra.sh ':

- -a  Sets action {azure-login, deploy-public-fabric, deploy-public-datasource, remove-public-fabric, remove-public-datasource, deploy-private-fabric, deploy-private-datasource, remove-private-fabric, remove-private-datasource,}
- -c  Sets the configuration file
- -e  Sets environment dev, staging, test, preprod, prod
- -t  Sets deployment Azure Tenant Id
- -s  Sets deployment Azure Subscription Id
- -r  Sets the Azure Region for the deployment

#### Connection to Azure

Follow the steps below to establish with your Azure Subscription where you want to deploy your infrastructure.

1. Launch the Azure login process using 'deploy-infra.sh -a azure-login'.
Usually this step is not required in a pipeline as the connection with Azure is already established.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a azure-login
    ```

    After this step the default Azure subscription has been selected. You can still change the Azure subscription, using Azure CLI command below:

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ az account set --subscription <azure-subscription-id>
    ```
    Using the command below you can define the Azure region, subscription, the tenant and the environment where Fabric will be deployed.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh -a azure-login -r <azure_region> -e dev -s <subscription_id> -t <tenant_id>
    ```

    After this step, the variables AZURE_REGION, AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID and AZURE_ENVIRONMENT used for the deployment are stored in the file ./.config/.default.env.
    The variable AZURE_DEFAULT_FABRIC_RESOURCE_GROUP and AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP are by default empty string.
    By default the name of the Fabric resource group will be 'rgpurview[AZURE_ENVIRONMENT][visibility][AZURE_SUFFIX]'
    the name of the Datasource resource group will be 'rgdatasource[AZURE_ENVIRONMENT][visibility][AZURE_SUFFIX]'
    where [visibility] value is 'pri' for private deployment and 'pub' for public deployment.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ cat ./.config/.default.env
        AZURE_REGION=westus3
        AZURE_SUFFIX=to-be-updated (4 digits)
        AZURE_SUBSCRIPTION_ID=to-be-updated
        AZURE_TENANT_ID=to-be-updated
        AZURE_ENVIRONMENT=dev
        AZURE_DEFAULT_FABRIC_RESOURCE_GROUP=""
        AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP=""
    ```

    In order to deploy the infrastructure with the script 'deploy-infra.sh ', you need to be connected to Azure with sufficient privileges to assign roles to Azure Key Vault and Azure Storage Accounts.
    Instead of using an interactive authentication session with Azure using your Azure account, you can use a service principal connection.

    If you don't have enough permission to create the resource groups for this deployment and you must reuse existing resource groups, you can set the values AZURE_DEFAULT_FABRIC_RESOURCE_GROUP, AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP in file ./.config/.default.env.

    For instance:

    ```bash
        AZURE_DEFAULT_FABRIC_RESOURCE_GROUP="fabric-test-rg"
        AZURE_DEFAULT_DATASOURCE_RESOURCE_GROUP="fabric-test-rg"
    ```

    If you don't have enough permission to deploy some resources in your subscription and you must reuse existing resources like Microsoft Fabric, Synapse Analytics Workspace, you can change the file [naming-convention.bicep](./bicep/naming-convention.bicep) to set the name of some resources.

    For instance:
    ```bash

      @description('The Azure Environment (dev, staging, preprod, prod,...)')
      @maxLength(13)
      param environment string = uniqueString(resourceGroup().id)

      @description('The cloud visibility (pub, pri)')
      @maxLength(7)
      param visibility string = 'pub'

      @description('The Azure suffix')
      @maxLength(4)
      param suffix string = '0000'


      var baseName = toLower('${environment}${visibility}${suffix}')

      output purviewAccountName string = 'fabric-test-myco'
      output vnetName string = 'vnet${baseName}'
      output storageAccountName string = 'sadataflowsmyco'
      output storageAccountDefaultContainerName string = 'test${baseName}'
      output keyVaultName string = 'sadataflowsmyco'
      output privateEndpointSubnetName string = 'snet${baseName}pe'
      output shirSubnetName string = 'snet${baseName}shir'
      output shirVMSSName string = 'vm${baseName}'
      output shirLoadBalancerName string = 'lbvm${baseName}'
      output vpnGatewayName string = 'vnetvpngateway${baseName}'
      output vpnGatewayPublicIpName string = 'vnetvpngatewaypip${baseName}'
      output dnsResolverName string = 'vnetdnsresolver${baseName}'
      output bastionSubnetName string = 'AzureBastionSubnet'
      output bastionHostName string = 'bastion${baseName}'
      output bastionPublicIpName string = 'bastionpip${baseName}'
      output gatewaySubnetName string = 'GatewaySubnet'
      output dnsDelegationSubNetName string = 'DNSDelegationSubnet'
      output purviewShirName string = 'SelfHostedIntegrationRuntime-${baseName}'
      output purviewVnetIrName string = 'IntegrationRuntime-${baseName}'
      output purviewManagedVnetName string = 'ManagedVnet-${baseName}'
      output purviewCollectionName string = 'fabric-test-myco'
      output purviewDataSourceName string = 'dstestmyco'
      output purviewScanRuleSetsName string = 'srstestmyco'
      output purviewScanName string = 'scantestmyco'
      output purviewShirKeyName string = 'SHIR-KEY'
      output purviewShirVMLoginSecretName string = 'SHIR-VM-LOGIN'
      output purviewShirVMPassSecretName string = 'SHIR-VM-PASSWORD'
      output baseName string = baseName
      output synapseWorkspaceName string = 'synapsemycotest'
      output synapseStorageAccountName string  = 'synapsest${baseName}'
      output synapseFileSystemName string = 'synapsefs${baseName}'
      output synapseSqlAdministratorLoginSecretName string = 'SYNAPSE-SQL-LOGIN'
      output synapseSqlAdministratorPassSecretName string = 'SYNAPSE-SQL-PASSWORD'
      output synapseSqlPoolName string = 'sql${baseName}'

      type SqlPoolSku = 'DW100c' | 'DW200c' | 'DW300c' | 'DW400c' | 'DW500c' | 'DW1000c' | 'DW1500c' | 'DW2000c' | 'DW2500c' | 'DW3000c'
      output synapseSqlPoolSku SqlPoolSku = 'DW100c'
      output synapseSparkPoolName string = 'spark${baseName}'

      type SparkNodeSize = 'Small' | 'Medium' | 'Large' | 'XLarge' | 'XXLarge'
      output synapseSparkPoolNodeSize SparkNodeSize = 'Small'
      output synapseSparkPoolMinNodeCount int = 3
      output synapseSparkPoolMaxNodeCount int = 5
      output synapseSparkPoolAutoScaleEnabled bool = true
      output synapseSparkPoolAutoPauseEnabled bool = true
      output synapseSparkPoolAutoPauseDelayInMinutes int = 15

      type SparkVersion = '2.4' | '3.1' | '3.2' | '3.3' | '3.4'
      output synapseSparkVersion SparkVersion = '3.4'
      output resourceGroupFabricName string = 'fabric-myco-test'
      output resourceGroupDatasourceName string = 'fabric-myco-test'
    ```

#### Deploying Fabric and Data Source with public endpoint

1. Once you are connected to your Azure subscription, you can now deploy a Fabric infrastructure associated with public endpoints.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a deploy-public-fabric
    ```

    After this step, the variables AZURE_SUFFIX and PURVIEW_PRINCIPAL_ID used for the deployment are stored in the file ./.config/.default.env.
    AZURE_SUFFIX is used to name the Azure resource. For a public endpoint deployement with suffix will be "${AZURE_ENVIRONMENT}pub${AZURE_SUFFIX}", and "${AZURE_ENVIRONMENT}pri${AZURE_SUFFIX}" for a deployment with private endpoints
    PURVIEW_PRINCIPAL_ID is the principal id of the managed identity associated with the Fabric account.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ cat ./.config/.default.env
        AZURE_REGION=westus3
        AZURE_SUBSCRIPTION_ID=to-be-completed
        AZURE_TENANT_ID=to-be-completed
        AZURE_ENVIRONMENT=dev
        AZURE_SUFFIX=3033
        PURVIEW_PRINCIPAL_ID=to-be-completed
    ```

    AZURE_REGION defines the Azure region where you want to install your infrastructure, it's 'westus3' by default.
    AZURE_SUFFIX defines the suffix which is used to name the Azure resources. By default this suffix includes 4 random digits which are used to avoid naming conflict when a resource with the same name has already been deployed in another subscription.
    AZURE_SUBSCRIPTION_ID is the Azure Subscription Id where you want to install your infrastructure
    AZURE_TENANT_ID is the Azure Tenant Id used for the authentication.
    AZURE_ENVIRONMENT defines the environment 'dev', 'stag', 'prod',...


2. Once Fabric is deployed into your Azure subscription, you can now deploy a datasources (Azure Storage Account ADLS gen2, Synapse Workspace, Synapse Azure Storage Account ADLS gen2, PostgreSQL pool) associated with public endpoints. This datasource will be accessible for the Fabric account.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a deploy-public-datasource
    ```
    After this step, dataset files are copied in the container 'test01' in the new storage.


3. From this stage, you can open the Fabric portal (https://web.fabric.azure.com/) to test scanning, classification and lineage scenarios.

4. You can also trigger an automated scan process using the command line below:

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a scan-public-datasource
    ```
    After this step, the number of assets discovered is displayed. This scan process is using the Azure Integration Runtime, you don't need to deploy a Self Hosted Integration Runtime nor a Managed VNET Integration Runtime.

5. Moreover, as Synapse Workspace, Synapse Azure Storage Account ADLS gen2, PostgreSQL pool have been deployed you can also create a Synapse pipeline and test lineage. You can for instance, follow the steps in this Lab ['Use Microsoft Fabric with Azure Synapse Analytics'](https://microsoftlearning.github.io/dp-203-azure-data-engineer/Instructions/Labs/22-Synapse-fabric.html)

6. When your test are over, you can remove the infrastructure running the following commands:

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a remove-public-fabric
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a remove-public-datasource
    ```


#### Deploying Fabric and Data Source with private endpoints

1. Once you are connected to your Azure subscription, you can now deploy a Fabric infrastructure associated with private endpoints.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a deploy-private-fabric
    ```

    After this step, the variables AZURE_SUFFIX and PURVIEW_PRINCIPAL_ID used for the deployment are stored in the file ./.config/.default.env.
    AZURE_SUFFIX is used to name the Azure resource. For a private endpoint deployement with suffix will be "${AZURE_ENVIRONMENT}pub${AZURE_SUFFIX}", and "${AZURE_ENVIRONMENT}pri${AZURE_SUFFIX}" for a deployment with private endpoints
    PURVIEW_PRINCIPAL_ID is the principal id of the managed identity associated with the Fabric account.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ cat ./.config/.default.env
        AZURE_REGION=westus3
        AZURE_SUBSCRIPTION_ID=to-be-completed
        AZURE_TENANT_ID=to-be-completed
        AZURE_ENVIRONMENT=dev
        AZURE_SUFFIX=3033
        PURVIEW_PRINCIPAL_ID=to-be-completed
    ```

    AZURE_REGION defines the Azure region where you want to install your infrastructure, it's 'westus3' by default.
    AZURE_SUFFIX defines the suffix which is used to name the Azure resources. By default this suffix includes 4 random digits which are used to avoid naming conflict when a resource with the same name has already been deployed in another subscription.
    AZURE_SUBSCRIPTION_ID is the Azure Subscription Id where you want to install your infrastructure
    AZURE_TENANT_ID is the Azure Tenant Id used for the authentication.
    AZURE_ENVIRONMENT defines the environment 'dev', 'stag', 'prod',...


2. Once Fabric is deployed into your Azure subscription, as all the new resources are connected to a virtual network with public access disabled, you need to establish a VPN connection to this virtual network before deploying data sources or Integration Runtimes.

3. As the Virtual Network is fully isolated, the VPN Gateway has been installed connected to the Virtual Network. You can now test this VPN Gateway.

4. Install Azure VPN Client on your machine. Windows version available [here](https://apps.microsoft.com/detail/9np355qt2sqb?hl=en-US&gl=US)

5. Open the [Azure portal](https://portal.azure.com), under the private Fabric resource group find the `virtual network gateway` resource.

6. Open it, navigate to `Settings`, `Point-to-site configuration` and select `Download VPN client`.

7. Unzip the zip file on your machine.

8. Launch the Azure VPN Client and import the file: `azurevpnconfig.xml` file in `AzureVPN` folder into the Azure VPN Client.

9. Click on the 'Connect' button, you'll need to enter your tenant credentials to establish a connection with the virtual machine.

10. Once you are connected you can open the Fabric portal url https://web.fabric.azure.com/, and check all the menus are accessible without any errors. From this stage, if necessary you can deploy either
 - Managed VNET Integration Runtime to scan data sources connected to a VNET and using Role Based Access Control
 - Self Hosted Integration Runtime to scan data sources using a Storage Account Key stored in the Key Vault or to scan data sources on premises

##### Deploying a data source (Azure Storage Account ADLS gen2 connected to a virtual network)

1. Once Fabric is deployed into your Azure subscription, you have access to the resources through the VPN connection, you can now deploy a datasource (Azure Storage Account ADLS gen2) associated with private endpoints. This datasource will be accessible for the Fabric account.

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a deploy-private-datasource
    ```
    After this step, dataset files are copied in the container 'test01' in the new storage.

##### Deploying Fabric Managed VNET Integration Runtime

1. If your data source is connected to a VNET through private endpoint and accessible with Role Based Access Control, you can deploy a Managed VNET Integration Runtime to scan your data sources running the following commands:

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a deploy-private-vnetir
    ```
2. This command will deploy the Managed VNET Integration Runtime, create the private endpoint and approve those endpoints. The Managed VNET Integration Runtime will be in 'Running' state after 10 minutes. After this stage, your infrastructure is ready to scan the data sources connected to the VNET.

##### Deploying Fabric Self Hosted Integration Runtime

1. If your data source is connected to a VNET through private endpoint and accessible using Storage Account Key, you can deploy a Self Hosted Integration Runtime to scan your data sources running the following commands:

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a deploy-private-shir
    ```
2. This command will deploy the Self Hosted Integration Runtime in Microsoft Fabric portal, deploy a virtual machine connected to the VNET. The Self Hosted Integration Runtime will be in 'Running' state after 15 minutes. After this stage, the infrastructure is ready to scan storage accounts connected to the same virtual network. The Azure Storage Acount Key will be stored in the Azure Key Vault in a specific secret which will be used by the virtual machine running the Self Hosted Integration Runtime.

##### Scanning the private datasource


1. As the Fabric Managed VNET Integration Runtime has been deployed, and as soon as the managed VNET Integration Runtime is in 'Running' status, you can trigger an automated scan process using the command line below:

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a scan-private-datasource
    ```

    After this step, the number of assets discovered is displayed. This scan process is using the Managed VNET Integration Runtime.

##### Removing the resources

1. When your tests are over, you can remove the infrastructure running the following commands:

    ```bash
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a remove-private-fabric
        vscode ➜ /workspaces/fabric-automated (main) $ ./infra/deploy-infra.sh   -a remove-private-datasource
    ```
