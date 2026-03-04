// Parameters
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

@description('The SKU name of the virtual machine scale set.')
param vmssSkuName string = 'Standard_B2ms'

@description('The SKU tier of virtual machines in a scale set.')
param vmssSkuTier string = 'Standard'

@description('The SKU capacity of virtual machines in a scale set.')
param vmssSkuCapacity int = 1

@description('The name of the administrator account.')
param administratorUsername string = 'VmssMainUser'

@description('The password of the administrator account.')
@secure()
param administratorPassword string

@description('The authentication key for the fabric integration runtime.')
@secure()
param purviewIntegrationRuntimeAuthKey string

module namingModule 'naming-convention.bicep' = {
  name: 'namingModule'
  params: {
    environment: env
    visibility: visibility
    suffix: suffix
  }
}


module shirvm 'shir.bicep' = {
  name: 'shirvmDeploy'
  scope: resourceGroup()
  params: {
    location: location
    vnetName: namingModule.outputs.vnetName
    subnetName: namingModule.outputs.shirSubnetName
    vmssName: namingModule.outputs.shirVMSSName
    loadbalancerName: namingModule.outputs.shirLoadBalancerName
    vmssSkuName:vmssSkuName
    vmssSkuTier:vmssSkuTier
    vmssSkuCapacity:vmssSkuCapacity
    administratorUsername:administratorUsername
    administratorPassword:administratorPassword
    purviewIntegrationRuntimeAuthKey: purviewIntegrationRuntimeAuthKey
  }
}
