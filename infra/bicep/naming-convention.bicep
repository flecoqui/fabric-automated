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

output fabricAccountName string = 'fabric${baseName}'
output fabricWorkspaceName string = 'workspace${baseName}'
output vnetName string = 'vnet${baseName}'
output storageAccountName string = 'st${baseName}'
output storageAccountDefaultContainerName string = 'test${baseName}'
output keyVaultName string = 'kv${baseName}'
output privateEndpointSubnetName string = 'snet${baseName}pe'
output datagwSubnetName string = 'snet${baseName}dtgw'
output datagwVMSSName string = 'vm${baseName}'
output datagwLoadBalancerName string = 'lbvm${baseName}'
output vpnGatewayName string = 'vnetvpngateway${baseName}'
output vpnGatewayPublicIpName string = 'vnetvpngatewaypip${baseName}'
output dnsResolverName string = 'vnetdnsresolver${baseName}'
output bastionSubnetName string = 'AzureBastionSubnet'
output bastionHostName string = 'bastion${baseName}'
output bastionPublicIpName string = 'bastionpip${baseName}'
output gatewaySubnetName string = 'GatewaySubnet'
output dnsDelegationSubNetName string = 'DNSDelegationSubnet'
output fabricShirName string = 'SelfHostedIntegrationRuntime-${baseName}'
output fabricVnetIrName string = 'IntegrationRuntime-${baseName}'
output fabricManagedVnetName string = 'ManagedVnet-${baseName}'
output fabricCollectionName string = 'fabric${baseName}'
output fabricDataSourceName string = 'ds${baseName}'
output fabricScanRuleSetsName string = 'srs${baseName}'
output fabricScanName string = 'scan${baseName}'
output fabricShirKeyName string = 'SHIR-KEY'
output fabricShirVMLoginSecretName string = 'SHIR-VM-LOGIN'
output fabricShirVMPassSecretName string = 'SHIR-VM-PASSWORD'
output baseName string = baseName
output postgreSqlServerName string = 'postgre${baseName}'
output postgreSqlAdministratorLoginSecretName string = 'POSTGRE-SQL-LOGIN'
output postgreSqlAdministratorPassSecretName string = 'POSTGRE-SQL-PASSWORD'
type SqlSku = 'Standard_D2ds_v4' | 'Standard_D4ds_v4' 
output postgreSqlSku SqlSku = 'Standard_D2ds_v4'
type sqlVersion = '11' | '12' | '13' | '14' | '15' | '16' | '17' | '18'
output postgreSqlVersion sqlVersion = '13'

output cosmosDBName string = 'cosmos${baseName}'

output resourceGroupFabricName string = 'rgfabric${baseName}'
output resourceGroupDatasourceName string = 'rgdatasource${baseName}'
