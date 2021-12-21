targetScope = 'resourceGroup'

@minLength(2)
@maxLength(10)
param name string

@minLength(2)
@maxLength(4)
param prefix string

param aspSku object = {
  name: 'F1'
  tier: 'Free'
  size: 'F1'
  family: 'Free'
  capacity: 1
}

@allowed([
  'app'
  'functionapp'
])
param kind string = 'app'

param sqlSkuName string = 'Standard'
param sqlSkuTier string = 'Standard'
param sqlSkuSize string = 'S0'

var aspName = '${prefix}-${name}-asp'
var appName = '${prefix}-${name}-app'
var sqlSrvName = '${prefix}-${name}-sqlsrv'
var sqlDbName = '${prefix}-${name}-sqldb'

//asp deploy
module asp '../../modules/arm/Microsoft.Web/serverfarms/deploy.bicep' = {
  name: 'asp-deploy-${uniqueString(resourceGroup().id, appName)}'
  params: {
    name: aspName
    sku: aspSku
  }
}

//app deploy
module app '../../modules/arm/Microsoft.Web/sites/deploy.bicep' = {
  name: 'app-deploy-${uniqueString(resourceGroup().id, appName)}'
  params: {
    name: appName
    kind: kind
    appServicePlanId: asp.outputs.appServicePlanResourceId
  }
}

//db deploy
module sql '../../modules/arm/Microsoft.Sql/servers/deploy.bicep' = {
  name: 'sql-deploy-${uniqueString(resourceGroup().id, appName)}'
  params: {
    name: sqlSrvName
    administratorLoginPassword: 'ThisIsASuperSecurePassw0rd!'
    administratorLogin: 'superadministrator'
    databases: [
      {
        name: sqlDbName
        serverName: sqlSrvName
        skuName: sqlSkuName
        tier: sqlSkuTier
        size: sqlSkuSize
        maxSizeBytes: 53687091200 //50GB -> 50*1024*1024*1024
        collation: 'SQL_Latin1_General_CP1_CI_AS'
      }
    ]
    firewallRules: [
      {
        name: 'AllowAzureTraffic'
        serverName: sqlSrvName
        startIpAddress: '0.0.0.0'
        endIpAddress: '0.0.0.0'
      }
    ]
  }
}
