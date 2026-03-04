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

output purviewAccountName string = 'pview${baseName}'
output vnetName string = 'vnet${baseName}'
output storageAccountName string = 'st${baseName}'
output storageAccountDefaultContainerName string = 'test${baseName}'
output keyVaultName string = 'kv${baseName}'
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
output purviewCollectionName string = 'pview${baseName}'
output purviewDataSourceName string = 'ds${baseName}'
output purviewScanRuleSetsName string = 'srs${baseName}'
output purviewScanName string = 'scan${baseName}'
output purviewShirKeyName string = 'SHIR-KEY'
output purviewShirVMLoginSecretName string = 'SHIR-VM-LOGIN'
output purviewShirVMPassSecretName string = 'SHIR-VM-PASSWORD'
output baseName string = baseName
output synapseWorkspaceName string = 'synapse${baseName}'
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
output resourceGroupPurviewName string = 'rgpurview${baseName}'
output resourceGroupDatasourceName string = 'rgdatasource${baseName}'
