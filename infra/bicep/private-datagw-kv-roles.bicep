param keyVaultName string
param principalId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

var roleKeyVaultSecretReader = '4633458b-17de-408a-b874-0445c86b69e6'
resource keyVaultSecretRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, roleKeyVaultSecretReader)
  scope: keyVault   // ✅ valid — same scope as this file
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleKeyVaultSecretReader)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
