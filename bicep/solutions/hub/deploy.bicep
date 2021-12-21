targetScope = 'subscription'
@minLength(2)
@maxLength(4)
param prefix string = 'hub' //platform subscription
param dcCount int = 2

param vnetAddressPrefixes array

var networkRgName = '${prefix}-network-rg'
var coreVnetName = '${prefix}-core-vnet'
var bastionName = '${prefix}-bst'
var firewallName = '${prefix}-fw'
var vnetGwName = '${prefix}-gw'
var vnetGwPipName = '${prefix}-gw-pip'
var appGwName = '${prefix}-agw'
var appGwPipName = '${appGwName}-pip'

var mgmtRgName = '${prefix}-mgmt-rg'
var mgmtKvName = '${prefix}-mgmt-secrets-kv'
var laMgmtWorkspaceName = '${prefix}-mgmt-monitor-ws'
var aaMgmtName = '${prefix}-mgmt-automation-aa'

var idRgName = '${prefix}-identity-rg'
var idRsvName = '${prefix}-identity-rsv'
var idKvName = '${prefix}-identity-kv'

//network group
module rgNet '../../modules/arm/Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: 'rg-network-deploy'
  params: {
    name: networkRgName
  }
}

//vnet deploy with subnets
module vnet '../../modules/arm/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'vnet-deploy'
  scope: resourceGroup(networkRgName)
  params: {
    name: coreVnetName
    addressPrefixes: vnetAddressPrefixes
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.1.0/24'
        delegations: []
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
      }
      {
        name: 'AppGatewaySubnet'
        addressPrefix: '10.0.2.0/24'
        delegations: []
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
      }
      {
        name: 'ADDSSubnet'
        addressPrefix: '10.0.3.0/24'
        delegations: []
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
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.4.0/24'
        delegations: []
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
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.5.0/24'
        delegations: []
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
      }
      
    ]
  }
  dependsOn: [
    rgNet
  ]
}

//bastion deploy
module bastion '../../modules/arm/Microsoft.Network/bastionHosts/deploy.bicep' = {
  name: 'bastion-deploy'
  scope: resourceGroup(networkRgName)
  params: {
    name: bastionName
    vNetId: vnet.outputs.virtualNetworkResourceId
  }
  dependsOn: [
    rgNet
  ]
}

//firewall deploy
module firewall '../../modules/arm/Microsoft.Network/azureFirewalls/deploy.bicep' = {
  name: 'firewall-deploy'
  scope: resourceGroup(networkRgName)
  params: {
    name: firewallName
    vNetId: vnet.outputs.virtualNetworkResourceId
  }
  dependsOn: [
    rgNet
  ]
}

//vnetgw deploy
module vnetGw '../../modules/arm/Microsoft.Network/virtualNetworkGateways/deploy.bicep' = {
  name: 'vnetGw-deploy'
  scope: resourceGroup(networkRgName)
  params: {
    name: vnetGwName
    virtualNetworkGatewaySku: 'VpnGw1'
    virtualNetworkGatewayType: 'Vpn'
    vNetResourceId: vnet.outputs.virtualNetworkResourceId
    gatewayPipName: [
      vnetGwPipName
    ]
  }
  dependsOn: [
    rgNet
  ]
}

//appgw deploy
module appGwPip '../../modules/arm/Microsoft.Network/publicIPAddresses/deploy.bicep' = {
  name: 'appGwPip-deploy'
  scope: resourceGroup(networkRgName)
  params: {
    name: appGwPipName
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
  }
  dependsOn: [
    rgNet
  ]
}
module appGw '../../modules/arm/Microsoft.Network/applicationGateways/deploy.bicep' = {
  name: 'appGw-deploy'
  scope: resourceGroup(networkRgName)
  params: {
    name: appGwName
    sku: 'Standard_v2'
    capacity: 1
    subnetName: vnet.outputs.subnetNames[1]
    frontendPublicIpResourceId: appGwPip.outputs.publicIPAddressResourceId
    frontendPrivateIpAddress: '10.0.2.4'
    backendPools: [
    {
      backendPoolName: 'defaultBackendPool'
      backendAddresses: []
    }
  ]
    backendHttpConfigurations: [
      {
        backendHttpConfigurationName: 'defaultBackendHttpConfig'
        port: 80
        protocol: 'http'
        cookieBasedAffinity: 'Disabled'
        pickHostNameFromBackendAddress: false
        probeEnabled: false
      }
    ]
    frontendHttpListeners: [
      {
        frontendListenerName: 'defaultFrontendHttpListener'
        frontendIPType: 'Public'
        port: 80
      }
    ]
    routingRules: [
      {
        frontendListenerName: 'defaultFrontendHttpListener'
        backendPoolName: 'defaultBackendPool'
        backendHttpConfigurationName: 'defaultBackendHttpConfig'
      }
    ]
    vNetName: vnet.outputs.virtualNetworkName
  }
  dependsOn: [
    rgNet
  ]
}

//mgmt group
module rgMgmt '../../modules/arm/Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: 'rg-mgmt-deploy'
  params: {
    name: mgmtRgName
  }
}

//kv deploy
module kvMgmt '../../modules/arm/Microsoft.KeyVault/vaults/deploy.bicep' = {
  name: 'kv-mgmt-deploy'
  scope: resourceGroup(mgmtRgName)
  params: {
    name: mgmtKvName
    enableRbacAuthorization: true
    roleAssignments: [
      {
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483' //Key Vault Administrator Role //Key Vault Administrator Role
        principalIds: [
          '87aac964-f0d0-440c-b4bb-a0e78e427fcf'
        ]
      }
    ]
    secrets: [
      {
        keyVaultName: mgmtKvName
        name: 'SuperSecret'
        value: 'Game of Thrones ending was OK..'
      }
    ]
  }
  dependsOn: [
    rgMgmt
  ]
}

//log analytics workspace deploy
module laMgmt '../../modules/arm/Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  name: 'la-mgmt-deploy'
  scope: resourceGroup(mgmtRgName)
  params: {
    name: laMgmtWorkspaceName
  }
  dependsOn: [
    rgMgmt
  ]
}

//automation account deploy
module aaMgmt '../../modules/arm/Microsoft.Automation/automationAccounts/deploy.bicep' = {
  name: 'aa-mgmt-deploy'
  scope: resourceGroup(mgmtRgName)
  params: {
    name: aaMgmtName
  }
  dependsOn: [
    rgMgmt
  ]
}

//identity group
module idRg '../../modules/arm/Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: 'rg-identity-deploy'
  params: {
    name: idRgName
  }
}

//nsgs for domain controllers
module nsgs '../../modules/arm/Microsoft.Network/networkSecurityGroups/deploy.bicep' = [for i in range(0,dcCount): {
  name: 'nsg-addsdcs${i}-deploy'
  scope: resourceGroup(idRgName)
  params: {
    name: 'adds-dc0${i}-nsg'
  }
  dependsOn: [
    idRg
  ]
}]

//domain controller vms
module vms '../../modules/arm/Microsoft.Compute/virtualMachines/deploy.bicep' = [for i in range(0,dcCount): {
  name: 'vm-addsdcs${i}-deploy'
  scope: resourceGroup(idRgName)
  params: {
    adminUsername: 'sysadmin'
    adminPassword: 'ThisIsASecurePassw0rd!123'
    availabilityZone: ( i % 2 ) + 1
    name: 'adds-dc0${i}'
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetId: '${vnet.outputs.virtualNetworkResourceId}/subnets/${vnet.outputs.subnetNames[2]}'
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
    idRg
  ]
}]

//rsv deploy
module rsv '../../modules/arm/Microsoft.RecoveryServices/vaults/deploy.bicep' = {
  name: 'rsv-addsdcs-deploy'
  scope: resourceGroup(idRgName)
  params: {
    name: idRsvName
  }
  dependsOn: [
    idRg
  ]
}

//kv deploy
module kvId '../../modules/arm/Microsoft.KeyVault/vaults/deploy.bicep' = {
  name: 'kv-identity-deploy'
  scope: resourceGroup(idRgName)
  params: {
    name: idKvName
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
        keyVaultName: idKvName
        name: 'SuperSecret'
        value: 'Windows is a far superior desktop client than Linux'
      }
    ]
  }
  dependsOn: [
    idRg
  ]
}

//private endpoint dns zones
//sqldb
//appservice

output coreVnetId string = vnet.outputs.virtualNetworkResourceId
output hubAzureFirewallIp string = firewall.outputs.azureFirewallPrivateIp
output networkRgName string = rgNet.outputs.resourceGroupName
