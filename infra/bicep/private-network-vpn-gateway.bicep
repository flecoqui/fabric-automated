@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The base name to be appended to all provisioned resources.')
@maxLength(13)
param baseName string = uniqueString(resourceGroup().id)

@description('The name of the virtual network.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param privateEndpointSubnetName string

@description('The name of the virtual network subnet to be used for Fabric Data Gateway subnet.')
param datagwSubnetName string

@description('The virtual network IP space to use for the new virutal network.')
param vnetAddressPrefix string

@description('The IP space to use for the subnet for private endpoints.')
param privateEndpointSubnetAddressPrefix string

@description('The IP space to use for the AzureBastionSubnet subnet.')
param bastionSubnetAddressPrefix string

@description('The IP space to use for Fabric Data Gateway.')
param datagwSubnetAddressPrefix string

@description('The IP address prefix for the virtual network subnet used for VPN Gateway.')
param gatewaySubnetAddressPrefix string

@description('The IP address prefix for the virtual network subnet used dns delegation.')
param dnsDelegationSubnetAddressPrefix string

@description('The IP address prefix for the virtual network subnet used dns delegation.')
param dnsDelegationSubnetIPAddress string

@description('The tags to be applied to the provisioned resources.')
param tags object

var gatewaySubnetName ='GatewaySubnet'
var dnsDelegationSubNetName = 'DNSDelegationSubnet'
var bastionSubnetName = 'AzureBastionSubnet'
var vpnGatewayName = 'vnet-vpn-gateway-${baseName}'
var vpnGatewayPublicIpName = 'vnet-vpn-gateway-pip-${baseName}'
var dnsResolverName = 'vnet-dns-resolver-${baseName}'

// Please note that though not required for the recipe, the "AzureBastionSubnet" subnet has been created to maintain idempotency of the deployment
// in case user decides to create a bastion host in the same VNet for testing purpose.
resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    dhcpOptions: { dnsServers: [dnsDelegationSubnetIPAddress] }
  }
}
// network security group for site
resource defaultNsgSubnet 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${vnetName}-default-nsg'
  location: location
  properties: {
    securityRules: []
  }
}

resource defaultSubNet 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  parent: vnet
  name: privateEndpointSubnetName
  properties: {
    addressPrefix: privateEndpointSubnetAddressPrefix
    networkSecurityGroup: {
      id: defaultNsgSubnet.id // Associate the NSG with the default subnet
    }
  }
}

resource datagwSubnetNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${vnetName}-datagw-nsg'
  location: location
  properties: {
    securityRules: []
  }
}

resource datagwSubNet 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  parent: vnet
  name: datagwSubnetName
  properties: {
    addressPrefix: datagwSubnetAddressPrefix
    networkSecurityGroup: {
      id: datagwSubnetNsg.id // Associate the NSG with the default subnet
    }
  }
  dependsOn: [
    defaultSubNet
  ]
}

resource bastionSubNet 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  parent: vnet
  name: bastionSubnetName
  properties: {
    addressPrefix: bastionSubnetAddressPrefix
  }
  dependsOn: [
    datagwSubNet
  ]
}


resource gatewaySubNet 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  parent: vnet
  name: gatewaySubnetName
  properties: {
    addressPrefix: gatewaySubnetAddressPrefix
  }
  dependsOn: [
    dnsDelegationSubNet
  ]
}

resource dnsDelegationSubnetNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${vnetName}-dns-delegation-nsg'
  location: location
  properties: {
    securityRules: []
  }
}

resource dnsDelegationSubNet 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  parent: vnet
  name: dnsDelegationSubNetName
  properties: {
    addressPrefix: dnsDelegationSubnetAddressPrefix
    networkSecurityGroup: {
      id: dnsDelegationSubnetNsg.id // Associate the NSG with the default subnet
    }
    delegations: [
      {
        name: 'Microsoft.Network.dnsResolvers'
        properties: {
          serviceName: 'Microsoft.Network/dnsResolvers'
        }
      }
    ]
  }
  dependsOn: [
    bastionSubNet
  ]
}


// ----------------------------------------------------
// LOCAL Private DNS Zone
// ----------------------------------------------------

resource privateDnsZoneLocal 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: '${baseName}.local'
  location: 'global'
}

// Link to VNET. Name should be the same as VNET as we can't have multiple links to the same VNET
resource vnetLinkLocal 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneLocal
  name: '${vnetName}-virtuallink'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: true
  }
  dependsOn: [
    dnsDelegationSubNet
  ]
}

// ------------------------------------------------------------------
// VPN Gateway
// ------------------------------------------------------------------

// Public IP for VPN Gateway
resource vpnGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: vpnGatewayPublicIpName
  location: location
  zones: ['1']
  properties: { publicIPAllocationMethod: 'Static' }
  sku: { name: 'Standard' }
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-07-01' = {
  name: vpnGatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: {
            id: vpnGatewayPublicIp.id
          }
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubNet.id
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          '172.16.201.0/24'
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'
      ]
      vpnAuthenticationTypes: [
        'AAD'
      ]
      aadAudience: 'c632b3df-fb67-4d84-bdcf-b95ad541b5c8'
      aadTenant: '${environment().authentication.loginEndpoint}${subscription().tenantId}/'
      aadIssuer: 'https://sts.windows.net/${subscription().tenantId}/'
    }
  }
}

// ---------------------------------------------------------
// DNS Resolver
// ---------------------------------------------------------
resource dnsResolver 'Microsoft.Network/dnsResolvers@2025-05-01' = {
  name: dnsResolverName
  location: location
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
  }
  dependsOn: [
    vnetLinkLocal //  Ensure the local VNET link is created before the DNS Resolver
  ]
}

// Inbound Endpoint for DNS Resolver
// Fixing the IP Address to a specific value for consistency and reference in VNET
resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01' = {
  parent: dnsResolver
  name: 'inboundEndpoint${baseName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        privateIpAddress: dnsDelegationSubnetIPAddress
        privateIpAllocationMethod: 'Static'
        subnet: {
          id: dnsDelegationSubNet.id
        }
      }
    ]
  }
}

output outVnetName string = vnet.name
output outVnetId string = vnet.id
output outPrivateEndpointSubnetName string = privateEndpointSubnetName
output outDataGWSubnetName string = datagwSubnetName
