targetScope = 'managementGroup'

param hubSubscriptionId string
param spoke1SubscriptionId string
param spoke2SubscriptionId string

var sharedConfig = json(loadTextContent('../../../../configs/shared-config.json'))

//deploy mgmt group treyresearch
module mgTopLevel '../../../modules/arm/Microsoft.Management/managementGroups/deploy.bicep' = {
  name: 'mg-toplevel-deploy'
  params: {
    name: sharedConfig['mg-root'].name
    parentId: sharedConfig['mg-root'].parentId
  }
}

//deploy mgmt group platform
module mgPlatform '../../../modules/arm/Microsoft.Management/managementGroups/deploy.bicep' = {
  name: 'mg-platform-deploy'
  params: {
    name: sharedConfig['mg-platform'].name
    parentId: last(split(mgTopLevel.outputs.managementGroupId, '/'))
  }
}

//deploy mgmt group landingzones
module mgLandingZones '../../../modules/arm/Microsoft.Management/managementGroups/deploy.bicep' = {
  name: 'mg-landingzones-deploy'
  params: {
    name: sharedConfig['mg-landingzones'].name
    parentId: last(split(mgTopLevel.outputs.managementGroupId, '/'))
  }
}

//deploy mgmt group online
module mgOnline '../../../modules/arm/Microsoft.Management/managementGroups/deploy.bicep' = {
  name: 'mg-online-deploy'
  params: {
    name: sharedConfig['mg-online'].name
    parentId: last(split(mgLandingZones.outputs.managementGroupId, '/'))
  }
}

//deploy mgmt group corp
module mgCorp '../../../modules/arm/Microsoft.Management/managementGroups/deploy.bicep' = {
  name: 'mg-corp-deploy'
  params: {
    name: sharedConfig['mg-corp'].name
    parentId: last(split(mgLandingZones.outputs.managementGroupId, '/'))
  }
}

//deploy hub in platform mgmt group - platform subscription
module hub '../../../solutions/hub/deploy.bicep' = {
  name: 'hub-deploy'
  scope: subscription(sharedConfig.platform.subscriptionId)
  params: {
    prefix: sharedConfig.platform.prefix
    vnetAddressPrefixes: sharedConfig.platform.vnetAddressPrefixes
  }
}

//deploy spoke 1 in landingzones -> online - spoke 1 subscription
module spoke1 '../../../solutions/spoke/deploy.bicep' = {
  name: 'spoke1-deploy'
  scope: subscription(spoke1SubscriptionId)
  params: {
    prefix: 'spk1'
    vnetAddressPrefixes: [
      '10.1.0.0/16'
    ]
    frontendSubnetPrefix: '10.1.0.0/24'
    backendSubnetPrefix: '10.1.1.0/24'
    aksSubnetPrefix: '10.1.2.0/24'
    hubNvaNextHop: hub.outputs.hubAzureFirewallIp
    aksConfiguration: []
    apps: [
      {
        name: 'app1'
      }
      {
        name: 'app2'
      }
    ]
  }
  dependsOn: [
    hub
  ]
}

module peeringHubToSpoke1 '../../../modules/arm/peering/deploy.bicep' = {
  name: 'peering-deploy-hubspk1'
  scope: resourceGroup(hubSubscriptionId,'hub-network-rg')
  params: {
    remoteVnetName: last(split(spoke1.outputs.coreVnetId,'/'))
    localVnetName: last(split(hub.outputs.coreVnetId,'/'))
    remoteVnetID: spoke1.outputs.coreVnetId
  }
  dependsOn: [
    hub
    spoke1
  ]
}

module peeringSpokeTo1Hub '../../../modules/arm/peering/deploy.bicep' = {
  name: 'peering-deploy-spk1hub'
  scope: resourceGroup(spoke1SubscriptionId,'spk1-network-rg')
  params: {
    remoteVnetName: last(split(hub.outputs.coreVnetId,'/'))
    localVnetName: last(split(spoke1.outputs.coreVnetId,'/'))
    remoteVnetID: hub.outputs.coreVnetId
  }
  dependsOn: [
    spoke1
    hub
  ]
}

module spoke2 '../../../solutions/spoke/deploy.bicep' = {
  name: 'spoke2-deploy'
  scope: subscription(spoke2SubscriptionId)
  params: {
    prefix: 'spk2'
    vnetAddressPrefixes: [
      '10.2.0.0/16'
    ]
    frontendSubnetPrefix: '10.2.0.0/24'
    backendSubnetPrefix: '10.2.1.0/24'
    aksSubnetPrefix: '10.2.2.0/24'
    hubNvaNextHop: hub.outputs.hubAzureFirewallIp
    aksConfiguration: [
      {
        baseName: 'spk2-cluster01'
        aadGroupIds: [
          'fcf6fa6a-f05a-45dd-a5a2-f22bbc9db105'
        ]
        rgName: 'spk2-aks-rg'
      }
    ]
  }
  dependsOn: [
    hub
  ]
}

module peeringHubToSpoke2 '../../../modules/arm/peering/deploy.bicep' = {
  name: 'peering-deploy-hubspk2'
  scope: resourceGroup(hubSubscriptionId,'hub-network-rg')
  params: {
    remoteVnetName: last(split(spoke2.outputs.coreVnetId,'/'))
    localVnetName: last(split(hub.outputs.coreVnetId,'/'))
    remoteVnetID: spoke2.outputs.coreVnetId
  }
  dependsOn: [
    hub
    spoke2
  ]
}

module peeringSpoke2ToHub '../../../modules/arm/peering/deploy.bicep' = {
  name: 'peering-deploy-spk2hub'
  scope: resourceGroup(spoke2SubscriptionId,'spk2-network-rg')
  params: {
    remoteVnetName: last(split(hub.outputs.coreVnetId,'/'))
    localVnetName: last(split(spoke2.outputs.coreVnetId,'/'))
    remoteVnetID: hub.outputs.coreVnetId
  }
  dependsOn: [
    spoke2
    hub
  ]
}
