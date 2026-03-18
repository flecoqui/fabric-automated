@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The Azure Environment (dev, staging, preprod, prod,...)')
@maxLength(7)
param env string = 'dev'

@description('The cloud visibility (pub, pri)')
@maxLength(7)
param visibility string = 'pub'

@description('The Azure suffix')
@maxLength(4)
param suffix string = '0000'

@description('The name of the Azure resource group containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneResourceGroupName string = resourceGroup().name

@description('The ID of the Azure subscription containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneSubscriptionId string = subscription().subscriptionId

@description('Indicator if new Azure Private DNS Zones should be created, or using existing Azure Private DNS Zones.')
@allowed([
  'new'
  'existing'
])
param newOrExistingDnsZones string = 'existing'

@description('The Sql administrator login of the administrator account.')
param sqlAdministratorLogin string

@description('The Sql administrator password of the administrator account.')
@secure()
param sqlAdministratorPassword string

@description('The SKU name of the virtual machine scale set.')
param vmSkuName string = 'Standard_B2ms'

@description('The name of the administrator account.')
param administratorUsername string = 'VmssMainUser'

@description('The password of the administrator account.')
@secure()
param administratorPassword string

@description('The authentication key for the fabric integration runtime.')
@secure()
param recoveryKey string

@description('The Fabric account principal ID.')
param fabricPrincipalId string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The client IP address.')
param clientIpAddress string = ''

@description('The application id used for the authentication of the data gateway with the tenant.')
param appId string = ''

module namingModule 'naming-convention.bicep' = {
  name: 'namingModule'
  params: {
    environment: env
    visibility: visibility
    suffix: suffix
  }
}

var tags = {
  baseName : namingModule.outputs.baseName
  environment: env
  visibility: visibility
  suffix: suffix
}
// Networking related variables
var vnetName =  namingModule.outputs.vnetName
var privateEndpointSubnetName = namingModule.outputs.privateEndpointSubnetName
// Azure Storage account related variables
var storageAccountName = namingModule.outputs.storageAccountName
var containerName = namingModule.outputs.storageAccountDefaultContainerName

// Defining Private DNS Zones resource group and subscription id
var calcDnsZoneResourceGroupName = (newOrExistingDnsZones == 'new') ? resourceGroup().name : dnsZoneResourceGroupName
var calcDnsZoneSubscriptionId = (newOrExistingDnsZones == 'new') ? subscription().subscriptionId : dnsZoneSubscriptionId

// Getting the Ids for existing or newly created Private DNS Zones
var dfsPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.dfs.${environment().suffixes.storage}')
var blobPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
var postgresqlPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.postgres.database.azure.com')
var cosmosdbPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.documents.azure.com')
var searchPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.search.windows.net')


///subscriptions/4b6e25b6-6b90-497a-9aa7-e673e32bc08c/resourceGroups/rgprivatepurview/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net
//var dfsPrivateDnsZoneId = resourceId('4b6e25b6-6b90-497a-9aa7-e673e32bc08c', 'rgprivatepurview', 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net')


///subscriptions/4b6e25b6-6b90-497a-9aa7-e673e32bc08c/resourceGroups/rgprivatepurview/providers/Microsoft.Network/privateDnsZones/privatelink.dfs.core.windows.net
//var blobPrivateDnsZoneId = resourceId('4b6e25b6-6b90-497a-9aa7-e673e32bc08c', 'rgprivatepurview', 'Microsoft.Network/privateDnsZones', 'privatelink.dfs.core.windows.net')




module storageModule 'private-storage.bicep' = {
  name: 'StorageDeploy'
  scope: resourceGroup()
  params: {
    location: location
    baseName: namingModule.outputs.baseName
    storageAccountName: storageAccountName
    defaultContainerName: containerName
    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    vnetResourceGroupName: dnsZoneResourceGroupName
    dfsPrivateDnsZoneId: dfsPrivateDnsZoneId
    blobPrivateDnsZoneId: blobPrivateDnsZoneId
    fabricPrincipalId: fabricPrincipalId
    objectId: objectId
    objectType: objectType
    clientIpAddress: clientIpAddress
    tags: tags
  }
}

module postgreSQLModule 'private-postgresql.bicep' = {
  name: 'PostgreSQLDeploy'
  scope: resourceGroup()
  params: {
    postgreSqlServerName: namingModule.outputs.postgreSqlServerName
    baseName: namingModule.outputs.baseName
    location: location
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    tags: tags
    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    vnetResourceGroupName: dnsZoneResourceGroupName
    postgresDnsZoneId: postgresqlPrivateDnsZoneId
  }
  dependsOn: [
  ]
}


module cosmosModule 'private-cosmosdb.bicep' = {
  name: 'CosmosDBDeploy'
  scope: resourceGroup()
  params: { 
    cosmosDBName: namingModule.outputs.cosmosDBName
    baseName: namingModule.outputs.baseName
    location: location
    objectId: objectId
    fabricPrincipalId: fabricPrincipalId
    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    vnetResourceGroupName: dnsZoneResourceGroupName
    cosmosDnsZoneId: cosmosdbPrivateDnsZoneId
    tags: tags
  }
  dependsOn: [
  ]
}


module searchModule 'private-search.bicep' = {
  name: 'SearchDeploy'
  scope: resourceGroup()
  params: {
    searchName: namingModule.outputs.searchName
    baseName: namingModule.outputs.baseName
    location: location
    tags: tags
    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    vnetResourceGroupName: dnsZoneResourceGroupName
    searchPrivateDnsZoneId: searchPrivateDnsZoneId
    fabricPrincipalId: fabricPrincipalId
    objectId: objectId
    objectType: objectType
  }
  dependsOn: [
  ]
}

module dataGatewayModule 'private-datagw.bicep' = {
  name: 'DataGatewayDeploy'
  scope: resourceGroup()
  params: {
    vmName: namingModule.outputs.datagwVMName
    baseName: namingModule.outputs.baseName
    location: location
    tags: tags
    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    vnetResourceGroupName: dnsZoneResourceGroupName
    vmSkuName: vmSkuName
    administratorUsername: administratorUsername
    administratorPassword: administratorPassword
    recoveryKey: recoveryKey
    objectId: objectId
    appId: appId
  }
  dependsOn: [
  ]
}

output outStorageAccountName string = storageModule.outputs.outStorageAccountName
output outStorageFilesysName string = storageModule.outputs.outStorageFilesysName
output postgresqlId string = postgreSQLModule.outputs.postgreSqlServerId
output postgresqlName string = postgreSQLModule.outputs.postgreSqlServerName  
output cosmosDBName string = cosmosModule.outputs.cosmosDBName
output cosmosDBId string = cosmosModule.outputs.cosmosDBId
output searchName string = searchModule.outputs.searchName
output searchId string = searchModule.outputs.searchId
output searchEndpoint string = searchModule.outputs.searchEndpoint
output datagwVMPrivateIp string = dataGatewayModule.outputs.privateIpAddress
output datagwVMResourceId string = dataGatewayModule.outputs.vmResourceId
