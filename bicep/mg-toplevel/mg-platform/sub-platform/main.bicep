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
module spokes '../../../solutions/spoke/deploy.bicep' = [for (item,index) in sharedConfig['spokes']: {
  name: 'spoke-${item.prefix}-deploy'
  scope: subscription(spoke1SubscriptionId)
  params: {
    prefix: item.prefix
    vnetAddressPrefixes: item.vnetAddressPrefixes
    frontendSubnetPrefix: '${split(item.vnetAddressPrefixes[0],'.')[0]}.${split(item.vnetAddressPrefixes[0],'.')[1]}.0.0/24'
    backendSubnetPrefix: '${split(item.vnetAddressPrefixes[0],'.')[0]}.${split(item.vnetAddressPrefixes[0],'.')[1]}.1.0/24'
    aksSubnetPrefix: '${split(item.vnetAddressPrefixes[0],'.')[0]}.${split(item.vnetAddressPrefixes[0],'.')[1]}.2.0/24'
    hubNvaNextHop: any(sharedConfig['platform'].firewallEnabled ? hub.outputs.hubAzureFirewallIp : null)
    aksConfiguration: item.aksConfig != [] ? item.aksConfig : null
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
}]

module hubpeerings '../../../modules/arm/peering/deploy.bicep' = [for (item, index) in sharedConfig['spokes']: {
  name: 'peering-deploy-hub-to-${item.prefix}'
  scope: resourceGroup(sharedConfig.platform.subscriptionId,'${sharedConfig.platform.prefix}-network-rg')
  params: {
    remoteVnetName: last(split(spokes[index].outputs.coreVnetId,'/'))
    localVnetName: last(split(hub.outputs.coreVnetId,'/'))
    remoteVnetID: spokes[index].outputs.coreVnetId
  }
  dependsOn: [
    hub
    spokes[index]
  ]
}]

module spokepeerings '../../../modules/arm/peering/deploy.bicep' = [for (item, index) in sharedConfig['spokes']: {
  name: 'peering-deploy-${item.prefix}-to-hub'
  scope: resourceGroup(spoke1SubscriptionId,'spk1-network-rg')
  params: {
    remoteVnetName: last(split(hub.outputs.coreVnetId,'/'))
    localVnetName: last(split(spokes[index].outputs.coreVnetId,'/'))
    remoteVnetID: hub.outputs.coreVnetId
  }
  dependsOn: [
    spokes[index]
    hub
  ]
}]
