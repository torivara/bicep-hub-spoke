targetScope = 'resourceGroup'

param principalId string
param roleDefinitionId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
param vnetName string

resource network 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  name: vnetName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(vnetName, last(split(roleDefinitionId,'/')))
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
  }
  scope: network
}
