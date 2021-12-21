targetScope = 'subscription'

param prefix string
param vmCount int = 2
param vnetAddressPrefixes array
param frontendSubnetPrefix string
param backendSubnetPrefix string
param aksSubnetPrefix string
param hubNvaNextHop string
param apps array = []
param aksConfiguration array = []

var networkRgName = '${prefix}-network-rg'
var coreVnetName = '${prefix}-core-vnet'
var frontendSubnetName = 'FrontendSubnet'
var frontendNsgName = '${coreVnetName}-${frontendSubnetName}-nsg'
var frontendRouteTableName = '${prefix}-${frontendSubnetName}-rt'
var backendSubnetName = 'BackendSubnet'
var backendNsgName = '${coreVnetName}-${backendSubnetName}-nsg'
var backendRouteTableName = '${prefix}-${backendSubnetName}-rt'

var appsRgName = '${prefix}-apps-rg'
var appRsvName = '${prefix}-app-rsv'
var appsKvName = '${prefix}-apps-kv'

//network group
module rgNet '../../modules/arm/Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: 'rg-network-deploy-${uniqueString(networkRgName)}'
  params: {
    name: networkRgName
  }
}

//vnet deploy
module vnet '../../modules/arm/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'vnet-deploy-${uniqueString(networkRgName)}'
  scope: resourceGroup(networkRgName)
  params: {
    name: coreVnetName
    addressPrefixes: vnetAddressPrefixes
    subnets: [
      {
        name: 'FrontendSubnet'
        addressPrefix: frontendSubnetPrefix
        delegations: []
        networkSecurityGroupName: frontendNsg.outputs.networkSecurityGroupName
        //prepare for future private endpoints
        privateEndpointNetworkPolicies: 'Disabled' // This property must be set to disabled for subnets that contain private endpoints. Default Value when not specified is "Enabled".
        serviceEndpoints: [
            {
                'service': 'Microsoft.Sql'
            }
            {
                'service': 'Microsoft.Storage'
            }
            {
                'service': 'Microsoft.KeyVault'
            }
            {
              'service': 'Microsoft.AzureCosmosDB'
            }
        ]
        routeTableName: frontendRouteTable.outputs.routeTableName
      }
      {
        name: 'BackendSubnet'
        addressPrefix: backendSubnetPrefix
        delegations: []
        networkSecurityGroupName: backendNsg.outputs.networkSecurityGroupName
        //prepare for future private endpoints
        privateEndpointNetworkPolicies: 'Disabled' // This property must be set to disabled for subnets that contain private endpoints. Default Value when not specified is "Enabled".
        serviceEndpoints: [
            {
                'service': 'Microsoft.Sql'
            }
            {
                'service': 'Microsoft.Storage'
            }
            {
                'service': 'Microsoft.KeyVault'
            }
            {
              'service': 'Microsoft.AzureCosmosDB'
            }
        ]
        routeTableName: backendRouteTable.outputs.routeTableName
      }
      
      {
        name: 'AksSubnet'
        addressPrefix: aksSubnetPrefix
        delegations: []
        networkSecurityGroupName: backendNsg.outputs.networkSecurityGroupName
        //prepare for future private endpoints
        privateEndpointNetworkPolicies: 'Disabled' // This property must be set to disabled for subnets that contain private endpoints. Default Value when not specified is "Enabled".
        serviceEndpoints: [
            {
                'service': 'Microsoft.Sql'
            }
            {
                'service': 'Microsoft.Storage'
            }
            {
                'service': 'Microsoft.KeyVault'
            }
            {
              'service': 'Microsoft.AzureCosmosDB'
            }
        ]
        routeTableName: backendRouteTable.outputs.routeTableName
      }
    ]
  }
  dependsOn: [
    rgNet
  ]
}

//nsg deploy
module frontendNsg '../../modules/arm/Microsoft.Network/networkSecurityGroups/deploy.bicep' =  {
  name: 'nsg-frontend-deploy-${uniqueString(networkRgName)}'
  scope: resourceGroup(networkRgName)
  params: {
    name: frontendNsgName
  }
  dependsOn: [
    rgNet
  ]
}

module backendNsg '../../modules/arm/Microsoft.Network/networkSecurityGroups/deploy.bicep' =  {
  name: 'nsg-backend-deploy-${uniqueString(networkRgName)}'
  scope: resourceGroup(networkRgName)
  params: {
    name: backendNsgName
  }
  dependsOn: [
    rgNet
  ]
}

//route table
module frontendRouteTable '../../modules/arm/Microsoft.Network/routeTables/deploy.bicep' = {
  name: 'rt-frontend-deploy-${uniqueString(networkRgName)}'
  scope: resourceGroup(networkRgName)
  params: {
    name: frontendRouteTableName
    routes: [
      {
        name: 'toInternet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubNvaNextHop
        }
      }
    ]
  }
  dependsOn: [
    rgNet
  ]
}

module backendRouteTable '../../modules/arm/Microsoft.Network/routeTables/deploy.bicep' = {
  name: 'rt-backend-deploy-${uniqueString(networkRgName)}'
  scope: resourceGroup(networkRgName)
  params: {
    name: backendRouteTableName
    routes: [
      {
        name: 'toInternet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubNvaNextHop
        }
      }
    ]
  }
  dependsOn: [
    rgNet
  ]
}

//app group
module rgApps '../../modules/arm/Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: 'rg-app-deploy-${uniqueString(appsRgName)}'
  params: {
    name: appsRgName
  }
}

//deploy app vms nsgs
module nsgs '../../modules/arm/Microsoft.Network/networkSecurityGroups/deploy.bicep' = [for i in range(0,vmCount): {
  name: 'nsg-app${i}-deploy'
  scope: resourceGroup(appsRgName)
  params: {
    name: 'adds-dc0${i}-nsg'
  }
  dependsOn: [
    rgApps
  ]
}]

//deploy app vms
module vms '../../modules/arm/Microsoft.Compute/virtualMachines/deploy.bicep' = [for i in range(0,vmCount): {
  name: 'vm-app${i}-deploy-${uniqueString(appsRgName)}'
  scope: resourceGroup(appsRgName)
  params: {
    adminUsername: 'sysadmin'
    adminPassword: 'ThisIsASecurePassw0rd!123'
    availabilityZone: ( i % 2 ) + 1
    name: '${prefix}-app${i}-vm'
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetId: '${vnet.outputs.virtualNetworkResourceId}/subnets/${vnet.outputs.subnetNames[0]}'
          }
        ]
        nsgId: nsgs[i].outputs.networkSecurityGroupResourceId
      }
    ]
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-Datacenter'
      version: 'latest'
    }
    osType: 'Windows'
    osDisk: {
        createOption: 'fromImage'
        diskSizeGB: 128
        managedDisk: {
            storageAccountType: 'Premium_LRS'
        }
    }
  }
  dependsOn: [
    rgApps
  ]
}]

//deploy rsv
module rsv '../../modules/arm/Microsoft.RecoveryServices/vaults/deploy.bicep' = {
  name: 'rsv-app-deploy-${uniqueString(appsRgName)}'
  scope: resourceGroup(appsRgName)
  params: {
    name: appRsvName
  }
  dependsOn: [
    rgApps
  ]
}

//deploy tieredapps with sql
module tieredApp '../tieredapp/deploy.bicep' = [for app in apps: {
  name: 'tieredapp-${app.name}-deploy'
  scope: resourceGroup(appsRgName)
  params: {
    name: app.name
    prefix: prefix
  }
  dependsOn: [
    rgApps
  ]
}]

//kv deploy
module kvApps '../../modules/arm/Microsoft.KeyVault/vaults/deploy.bicep' = {
  name: 'kv-apps-deploy-${uniqueString(appsRgName)}'
  scope: resourceGroup(appsRgName)
  params: {
    name: appsKvName
    enableRbacAuthorization: true
    roleAssignments: [
      {
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483' //Key Vault Administrator Role
        principalIds: [
          '87aac964-f0d0-440c-b4bb-a0e78e427fcf'
        ]
      }
    ]
    secrets: [
      {
        keyVaultName: appsKvName
        name: 'ConfidentialSecret'
        value: 'Visual Studio Code is not a good developer tool. PowerShell ISE is way better!'
      }
    ]
  }
  dependsOn: [
    rgApps
  ]
}

module rgAks '../../modules/arm/Microsoft.Resources/resourceGroups/deploy.bicep' = [for cluster in aksConfiguration: {
  name: 'rg-aks-deploy-${uniqueString(cluster.rgName)}'
  params: {
    name: cluster.rgName
  }
}]

module aks '../aks/main.bicep' = [for cluster in aksConfiguration: {
  name: 'aks-deploy-${uniqueString(cluster.rgName)}'
  scope: resourceGroup(cluster.rgName)
  params: {
    aadGroupIds: cluster.aadGroupIds
    vnetResourceId: vnet.outputs.virtualNetworkResourceId
    baseName: cluster.baseName
  }
  dependsOn: [
    rgAks
  ]
}]

module networkContributor 'role.bicep' = [for (cluster, i) in aksConfiguration: {
  name: 'network-contributor-${uniqueString(cluster.baseName)}-deploy'
  scope: resourceGroup(networkRgName)
  params: {
    principalId: aks[i].outputs.aksUserAssignedIdentity
    vnetName: vnet.outputs.virtualNetworkName
  }
}]

output networkRgName string = rgNet.outputs.resourceGroupName
output coreVnetId string = vnet.outputs.virtualNetworkResourceId
