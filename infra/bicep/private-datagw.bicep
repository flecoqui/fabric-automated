// Parameters
@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The Virtual Machine Scale Set name.')
param vmName string

@description('The base name appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('The Virtual Network name.')
param vnetName string

@description('The Subnet name.')
param subnetName string

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
// Variables
var subnetId = '${resourceId('Microsoft.Network/virtualNetworks', vnetName)}/subnets/${subnetName}'


resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-datagw-${baseName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}


// -------------------------
// Windows VM
// -------------------------
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSkuName
    }
    osProfile: {
      computerName: vmName
      adminUsername: administratorUsername
      adminPassword: administratorPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
      customData: loadFileAsBase64('../scripts/installDataGateway.ps1')
    }
    storageProfile: {
      imageReference: {
          offer: 'WindowsServer'
          publisher: 'MicrosoftWindowsServer'
          sku: '2022-datacenter-azure-edition'
          version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
  tags: tags
}

resource extension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: vm
   name: '${vmName}-datagw-integrationruntime'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -NoProfile -NonInteractive -command "cp c:/azuredata/customdata.bin c:/azuredata/installDataGateway.ps1; c:/azuredata/installDataGateway.ps1 -gatewayName ${vmName} -recoveryKey "${recoveryKey}"'
    }
  }
  tags: tags
}


output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmResourceId string = vm.id
