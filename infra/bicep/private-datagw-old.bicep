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
param vmSkuName string = 'Standard_B2ms'

@description('The name of the administrator account.')
param administratorUsername string = 'VmssMainUser'

@description('The password of the administrator account.')
@secure()
param administratorPassword string

@description('The authentication key for the fabric integration runtime.')
@secure()
param recoveryKey string

@description('The tags to be applied to the provisioned resources.')
param tags object

module namingModule 'naming-convention.bicep' = {
  name: 'namingModule'
  params: {
    environment: env
    visibility: visibility
    suffix: suffix
  }
}


module datagwvm 'datagw.bicep' = {
  name: 'datagwvmDeploy'
  scope: resourceGroup()
  params: {
    location: location
    vmName: namingModule.outputs.datagwVMName
    baseName: namingModule.outputs.baseName
    vmSkuName:vmSkuName
    vnetName: namingModule.outputs.vnetName
    subnetName: namingModule.outputs.datagwSubnetName
    administratorUsername:administratorUsername
    administratorPassword:administratorPassword
    recoveryKey: recoveryKey
    tags: tags
  }
}

output privateIpAddress string = datagwvm.outputs.privateIpAddress
output vmResourceId string = datagwvm.outputs.vmResourceId
