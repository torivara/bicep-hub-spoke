targetScope = 'resourceGroup'

// Parameters
param baseName string
param aadGroupIds array
param vnetResourceId string
param acrSubnetName string = 'BackendSubnet'

param aksClusterDockerBridgeCidr string = '172.17.0.1/16'
param aksClusterServiceCidr string = '10.0.0.0/16'
param aksClusterDnsServiceIp string = '10.0.0.10'

// Variables
var rgName = '${baseName}-RG'

// Must be unique name
var acrName = '${uniqueString(rgName)}acr'

var lawName = '${baseName}-law'

var identityName = '${baseName}-id'

var aksName = '${baseName}-cluster-aks'
var aksSubnetName = 'aksSubnet'

module acrDeploy '../../modules/arm/Microsoft.ContainerRegistry/registries/deploy.bicep' = {
  name: 'acrDeploy-${uniqueString(aksName)}'
  params: {
    name: acrName
    acrSku: 'Premium'
  }
}

module acrpvtEndpoint '../../modules/arm/Microsoft.Network/privateEndpoints/deploy.bicep' = {
  name: 'acrpvtEndpoint-${uniqueString(aksName)}'
  params: {
    name: 'acrpvtEndpointConnection'
    groupId: [
      'registry'
    ]
    serviceResourceId: acrDeploy.outputs.acrResourceId
    targetSubnetResourceId: '${vnetResourceId}/subnets/${acrSubnetName}'
  }
}

module privatednsACRZone '../../modules/arm/Microsoft.Network/privateDnsZones/deploy.bicep' = {
  name: 'privatednsACRZone-${uniqueString(aksName)}'
  params: {
    name: 'privatelink.azurecr.io'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnetResourceId
        registrationEnabled: false
      }
    ]
  }
}

module akslaworkspace '../../modules/arm/Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  name: 'akslaworkspace-${uniqueString(aksName)}'
  params: {
    name: lawName
  }
}

module privatednsAKSZone '../../modules/arm/Microsoft.Network/privateDnsZones/deploy.bicep' = {
  name: 'privatednsAKSZone-${uniqueString(aksName)}'
  params: {
    name: 'privatelink.${resourceGroup().location}.azmk8s.io'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnetResourceId
        registrationEnabled: false
      }
    ]
    roleAssignments: [
      {
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b12aa53e-6015-4669-85d0-8515ebb3ae7f') //Private DNS Zone Contributor
        principalIds: [
            aksIdentity.outputs.msiPrincipalId // AKS user assigned identity
        ]
      }
    ]
  }
}

module aksIdentity '../../modules/arm/Microsoft.ManagedIdentity/userAssignedIdentities/deploy.bicep' = {
  name: 'aksIdentity-${uniqueString(aksName)}'
  params: {
    name: identityName
  }
}

module aksCluster '../../modules/arm/Microsoft.ContainerService/managedClusters/deploy.bicep' = {
  name: 'aksCluster-${uniqueString(aksName)}'
  params: {
    name: aksName
    nodeResourceGroup: '${baseName}-aksnodes-rg'
    aksClusterKubernetesVersion: '1.21.2'
    aksClusterDnsPrefix: '${baseName}aks'
    aadProfileAdminGroupObjectIDs: aadGroupIds
    aadProfileEnableAzureRBAC: true
    omsAgentEnabled: true
    workspaceId: akslaworkspace.outputs.logAnalyticsResourceId
    aksClusterEnablePrivateCluster: true
    privateDnsZoneId: privatednsAKSZone.outputs.privateDnsZoneResourceId
    aksServicePrincipalProfile: {
      clientID: aksIdentity.outputs.msiPrincipalId
    }
    userAssignedIdentities: {
      '${aksIdentity.outputs.msiResourceId}' : {}
    }
    primaryAgentPoolProfile: [
      {
        name: 'default'
        count: 1
        vmSize: 'Standard_D2s_v3'
        mode: 'System'
        maxCount: 2
        minCount: 1
        maxPods: 50
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: '${vnetResourceId}/subnets/${aksSubnetName}'
      }
    ]
    aksClusterLoadBalancerSku: 'standard'
    aksClusterNetworkPlugin: 'azure'
    aksClusterOutboundType: 'userDefinedRouting'
    aksClusterDockerBridgeCidr: aksClusterDockerBridgeCidr
    aksClusterDnsServiceIP: aksClusterDnsServiceIp
    aksClusterServiceCidr: aksClusterServiceCidr
    aksClusterNetworkPolicy: 'azure'
  }
}

output aksUserAssignedIdentity string = aksIdentity.outputs.msiPrincipalId
