@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The Azure Environment (dev, staging, preprod, prod,...)')
@maxLength(7)
param env string = 'dev'

@description('The cloud visibility (pub, pri)')
@maxLength(7)
param visibility string = 'pri'

@description('The Azure suffix')
@maxLength(4)
param suffix string = '0000'

@description('The fabric sku.')
@allowed([
  'F2'
  'F4'
  'F8'
  'F16'
  'F32'
  'F64'
  'F128'
  'F256'
  'F512'
  'F1024'
  'F2048'
])
param fabricSKU string = 'F2'

@description('The IP address prefix for the virtual network')
param vnetAddressPrefix string = '10.13.0.0/16'

@description('The IP address prefix for the virtual network subnet used for private endpoints.')
param privateEndpointSubnetAddressPrefix string = '10.13.0.0/24'

@description('The IP address prefix for the virtual network subnet used for AzureBastionSubnet subnet.')
param bastionSubnetAddressPrefix string =  '10.13.1.0/24'

@description('The IP address prefix for the virtual network subnet used for Fabric Data gateaway subnet.')
param datagwSubnetAddressPrefix string =  '10.13.2.0/24'

@description('The IP address prefix for the virtual network subnet used for VPN Gateway.')
param gatewaySubnetAddressPrefix string = '10.13.3.0/24'

@description('The IP address prefix for the virtual network subnet used dns delegation.')
param dnsDelegationSubnetAddressPrefix string = '10.13.4.0/24'

@description('The IP address prefix for the virtual network subnet used dns delegation.')
param dnsDelegationSubnetIPAddress string = '10.13.4.22'

@description('The name of the Azure resource group containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneResourceGroupName string = resourceGroup().name

@description('The ID of the Azure subscription containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneSubscriptionId string = subscription().subscriptionId

@description('Indicator if new Azure Private DNS Zones should be created, or using existing Azure Private DNS Zones.')
@allowed([
  'new'
  'existing'
])
param newOrExistingDnsZones string = 'new'

@description('The principal name of the user or service principal running the script.')
param principalName string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

module namingModule 'naming-convention.bicep' = {
  name: 'namingModule'
  params: {
    environment: env
    visibility: visibility
    suffix: suffix
  }
}
var baseName = namingModule.outputs.baseName
var tags = {
  baseName : baseName
}

// Networking related variables
var vnetName = namingModule.outputs.vnetName
var privateEndpointSubnetName = namingModule.outputs.privateEndpointSubnetName
var datagwSubnetName = namingModule.outputs.datagwSubnetName
// Azure Key Vault related variables
var keyVaultName = namingModule.outputs.keyVaultName
// Fabric
var fabricAccountName = namingModule.outputs.fabricAccountName

// Private DNS Zone variables
var privateDnsNames = [
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.dfs.${environment().suffixes.storage}'
  'privatelink.postgres.database.azure.com'
  'privatelink.documents.azure.com'
  'privatelink.search.windows.net'
]

// Defining Private DNS Zones resource group and subscription id
var calcDnsZoneResourceGroupName = (newOrExistingDnsZones == 'new') ? resourceGroup().name : dnsZoneResourceGroupName
var calcDnsZoneSubscriptionId = (newOrExistingDnsZones == 'new') ? subscription().subscriptionId : dnsZoneSubscriptionId

// Getting the Ids for existing or newly created Private DNS Zones
var keyVaultPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')


module dnsZoneModule './private-dns-zones.bicep' = if (newOrExistingDnsZones == 'new') {
  name: 'dnsZoneDeploy'
  scope: resourceGroup()
  params: {
    privateDnsNames: privateDnsNames
    tags: tags
  }
}

module networkModule 'private-network-vpn-gateway.bicep' = {
  name: 'networkDeploy'
  scope: resourceGroup()
  params: {
    location: location
    baseName: baseName
    vnetName: vnetName
    privateEndpointSubnetName: privateEndpointSubnetName
    datagwSubnetName: datagwSubnetName
    vnetAddressPrefix: vnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
    datagwSubnetAddressPrefix: datagwSubnetAddressPrefix
    gatewaySubnetAddressPrefix: gatewaySubnetAddressPrefix
    dnsDelegationSubnetIPAddress: dnsDelegationSubnetIPAddress
    dnsDelegationSubnetAddressPrefix: dnsDelegationSubnetAddressPrefix
    tags: tags
  }
}

module privateDnsZoneVnetLinkModule './dns-zone-vnet-mapping.bicep' = [ for (names, i) in privateDnsNames: {
  name: 'privateDnsZoneVnetLinkDeploy-${i}'
  scope: resourceGroup(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName)
  params: {
    privateDnsZoneName: names
    vnetId: networkModule.outputs.outVnetId
    vnetLinkName: '${networkModule.outputs.outVnetName}-link'
  }
  dependsOn: [
    dnsZoneModule
  ]
}]

module keyVaultModule 'private-keyvault.bicep' = {
  name: 'keyVaultDeploy'
  scope: resourceGroup()
  params: {
    location: location
    baseName: baseName
    keyVaultName: keyVaultName
    keyVaultPrivateDnsZoneId: keyVaultPrivateDnsZoneId
    vnetName: networkModule.outputs.outVnetName
    subnetName: networkModule.outputs.outPrivateEndpointSubnetName
    objectId: objectId 
    objectType: objectType
    tags: tags
  }
  dependsOn: [
    privateDnsZoneVnetLinkModule
  ]
}

module fabricModule 'private-fabric.bicep' = {
  name: 'FabricDeploy'
  scope: resourceGroup()
  params: {
    location: location
    fabricAccountName: fabricAccountName
    fabricSku: fabricSKU
    fabricAdminId: principalName
    tags: tags
  }
}

output outVirtualNetworkName string = networkModule.outputs.outVnetName
output outPrivateEndpointSubnetName string = networkModule.outputs.outPrivateEndpointSubnetName
output outDataGWSubnetName string = networkModule.outputs.outDataGWSubnetName
output outKeyVaultName string = keyVaultModule.outputs.outKeyVaultName
output outFabricAccountName string = fabricModule.outputs.outFabricAccountName
